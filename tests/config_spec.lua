-- Run: XDG_STATE_HOME=$(mktemp -d) nvim --headless -u NONE -i NONE -l tests/config_spec.lua
local root = vim.fn.getcwd()
local fixture = vim.fn.tempname()
vim.fn.mkdir(fixture, "p")
local failures = {}
local function check(condition, message)
  assert(condition, message)
end
local function wait(predicate, message)
  check(vim.wait(4000, predicate, 10), message or "Timed out")
end
local function test(name, callback)
  local ok, err = xpcall(callback, debug.traceback)
  if ok then
    print("PASS " .. name)
  else
    failures[#failures + 1] = name .. "\n" .. err
    print("FAIL " .. name .. "\n" .. err)
  end
end
local function read(path)
  return table.concat(vim.fn.readfile(path, "b"), "\n")
end
local function git(dir, args)
  local command = { "git", "-C", dir, "-c", "user.name=Config Test", "-c", "user.email=config@example.invalid" }
  vim.list_extend(command, args)
  local result = vim.system(command, { text = true }):wait()
  check(result.code == 0, result.stderr)
  return vim.trim(result.stdout or "")
end
local function repository(name)
  local path = fixture .. "/" .. name
  vim.fn.mkdir(path, "p")
  git(path, { "init", "-q", "-b", "main" })
  vim.fn.writefile({ "original  ", "", "" }, path .. "/sample.txt")
  git(path, { "add", "." })
  git(path, { "commit", "-qm", "Initial" })
  return path
end
local function invoke(key, mode)
  local map = vim.fn.maparg(key, mode or "n", false, true)
  check(type(map.callback) == "function" or map.rhs, "Missing mapping for " .. key)
  if type(map.callback) == "function" then
    map.callback()
  else
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(map.lhs, true, false, true), "xt", false)
  end
end
local notices = {}
local executable = vim.fn.executable
-- Startup smoke test uses the full config, without changing the desktop input method.
vim.fn.executable = function(command)
  if command == "fcitx5-remote" then
    return 0
  end
  return executable(command)
end
vim.env.TCSTORY_NVIM_AUTOSAVE = nil
vim.o.loadplugins = true
dofile(root .. "/init.lua")
vim.wait(150)
vim.fn.executable = executable
vim.notify = function(message, level)
  notices[#notices + 1] = { message = message, level = level }
end
local repo = repository("first")
local other = repository("second")

local lib
local source
local baseline
local function close_diff()
  require("diffview").close()
  vim.wait(50)
end

test("startup and portable dependencies", function()
  check(require("config.autosave").enabled == false, "Autosave unexpectedly enabled")
  check(require("lazy.core.config").plugins["native-history"] ~= nil, "Missing native history")
  check(require("lazy.core.config").plugins["local-history"] == nil, "Old timer plugin still loaded")
  check(vim.lsp.config.vtsls.cmd[1] == vim.fn.exepath("node"), "LSP did not resolve Node from PATH")
  local plugin = require("lazy.core.config").plugins["diffview-plus.nvim"]
  check(plugin.url:find("tcstory/diffview-plus.nvim", 1, true), "Wrong Diffview repository")
  check(plugin.commit == "712430437db4edc605236723ae0f6bf8ef21d28c", "Diffview revision not pinned")
end)

test("dashboard number callback survives repeated refresh", function()
  local sections = vim.deepcopy(require("plugins.snacks").opts.dashboard.sections)
  for _, section in ipairs(sections) do
    if section.section == "projects" then
      section.dirs = { repo }
    end
  end
  local dashboard = Snacks.dashboard.open({ win = 0, sections = sections })
  for _ = 1, 3 do
    dashboard:update()
    vim.cmd.tcd(other)
    local count = #notices
    invoke("1")
    check(vim.fn.getcwd(-1, 0) == repo, "Dashboard did not change tab cwd")
    check(
      #notices == count + 1 and notices[#notices].message == "已切换工作区: " .. repo,
      "Missing workspace notification"
    )
  end
  vim.cmd.enew()
end)

test("Diff This compares unsaved buffer and preserves HEAD bytes", function()
  vim.cmd.edit(repo .. "/sample.txt")
  source = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(source, 0, -1, false, { "unsaved change" })
  require("lazy").load({ plugins = { "gitsigns.nvim" } })
  invoke("<leader>gd")
  lib = require("diffview.lib")
  wait(function()
    return lib.get_current_view() ~= nil
  end)
  local view = lib.get_current_view()
  baseline = view.left_path
  check(baseline ~= nil, "Diffview file comparison was not opened")
  check(read(baseline) == "original  \n\n\n", "HEAD whitespace was lost")
  wait(function()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_buf(win) == source then
        return true
      end
    end
    return false
  end, "Diffview did not reuse the unsaved source buffer")
  check(vim.bo[source].modified, "Diff This saved the buffer")
  check(read(repo .. "/sample.txt") == "original  \n\n\n", "Diff This modified disk")
  close_diff()
  wait(function()
    return vim.fn.filereadable(baseline) == 0
  end, "HEAD snapshot not cleaned up")
  vim.cmd.edit({ args = { repo .. "/sample.txt" }, bang = true })
  vim.cmd("edit!")
end)

test("Diff This handles unchanged buffers, spaces, CRLF and missing final newline", function()
  local tab = vim.api.nvim_get_current_tabpage()
  invoke("<leader>gd")
  check(vim.api.nvim_get_current_tabpage() == tab and lib.get_current_view() == nil, "Unchanged buffer opened a diff")
  for _, case in ipairs({ { "space crlf.txt", "first  \r\n\r\n" }, { "no final newline.txt", "last  " } }) do
    local path = repo .. "/" .. case[1]
    local handle = assert(io.open(path, "wb"))
    handle:write(case[2])
    handle:close()
    git(repo, { "add", case[1] })
    git(repo, { "commit", "-qm", case[1] })
    vim.cmd.edit(path)
    invoke("<leader>gd")
    check(lib.get_current_view() == nil, "Unchanged file was incorrectly marked modified")
    vim.api.nvim_buf_set_lines(0, 0, 1, false, { "changed" })
    invoke("<leader>gd")
    wait(function()
      return lib.get_current_view() ~= nil
    end)
    check(read(lib.get_current_view().left_path) == case[2], "HEAD byte snapshot was changed")
    close_diff()
    vim.cmd("edit!")
  end
  vim.cmd.edit(repo .. "/sample.txt")
end)

test("history command never saves source; autosave uses normal write events", function()
  local autosave = require("config.autosave")
  check(vim.o.undofile, "Persistent undo is disabled")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "not yet saved" })
  local original = read(repo .. "/sample.txt")
  local writes = 0
  local group = vim.api.nvim_create_augroup("config_test_writes", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    buffer = vim.api.nvim_get_current_buf(),
    callback = function()
      writes = writes + 1
    end,
  })
  local picker = Snacks.picker.undo
  local opened = false
  Snacks.picker.undo = function()
    opened = true
  end
  invoke("<leader>su")
  Snacks.picker.undo = picker
  vim.api.nvim_exec_autocmds("FocusLost", {})
  vim.wait(100)
  check(opened and writes == 0 and read(repo .. "/sample.txt") == original, "History saved the source")
  vim.env.TCSTORY_NVIM_AUTOSAVE = "1"
  package.loaded["config.autosave"] = nil
  local enabled = require("config.autosave")
  check(enabled.enabled, "Explicit autosave did not enable")
  vim.api.nvim_exec_autocmds("FocusLost", {})
  local saved = { writes = writes, disk = read(repo .. "/sample.txt") }
  check(saved.writes == 1 and saved.disk == "not yet saved\n", "Autosave write mismatch: " .. vim.inspect(saved))
  enabled.enabled = false
  package.loaded["config.autosave"] = autosave
  vim.api.nvim_del_augroup_by_id(group)
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { "original  ", "", "" })
  vim.cmd.write()
end)

test("Git Blame resolves the exact source with multiple files open", function()
  vim.cmd.edit(repo .. "/sample.txt")
  vim.cmd.vsplit(other .. "/sample.txt")
  wait(function()
    return require("gitsigns.cache").cache[vim.api.nvim_get_current_buf()] ~= nil
  end, "Gitsigns did not attach")
  vim.cmd("Gitsigns blame")
  wait(function()
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "gitsigns-blame" then
        vim.api.nvim_set_current_win(win)
        return true
      end
    end
    return false
  end, "Blame window missing")
  local blame_win = vim.api.nvim_get_current_win()
  local helper = require("config.git")
  local info = helper.get_blame_commit_at_line(blame_win, 1)
  check(
    info and info.cwd == other and info.sha == git(other, { "rev-parse", "HEAD" }),
    "Blame used another file/repository"
  )
  -- Invalidate just this cache to exercise the real panel-text fallback.
  local cache = require("gitsigns.cache").cache
  local source_buf = vim.b.tcstory_blame_source.buf
  local saved = cache[source_buf].blame
  cache[source_buf].blame = nil
  local fallback = helper.get_blame_commit_at_line(blame_win, 2)
  check(fallback and fallback.sha == info.sha:sub(1, #fallback.sha), "Blame fallback failed on continuation line")
  cache[source_buf].blame = saved
  wait(function()
    return vim.fn.maparg("d", "n", false, true).desc == "Show Commit Diff"
  end, "Custom blame key was overwritten")
  invoke("d")
  wait(function()
    return lib.get_current_view() ~= nil
  end)
  check(lib.get_current_view().adapter.ctx.toplevel == other, "Commit diff opened in wrong repository")
  close_diff()
end)

test("terminal keys reuse objects across directories and tabs", function()
  vim.cmd.tcd(repo)
  vim.o.shell = "/bin/sh"
  invoke("<C-\\>")
  local terminal = require("config.terminal")
  wait(function()
    return #terminal.list() == 1 and vim.bo.buftype == "terminal"
  end)
  local first_buf = vim.api.nvim_get_current_buf()
  terminal.hide()
  vim.cmd.tcd(other)
  invoke("<C-\\>")
  wait(function()
    return vim.api.nvim_get_current_buf() == first_buf
  end)
  check(#terminal.list() == 1 and vim.b.snacks_terminal.cwd == repo, "Switching cwd duplicated terminal")
  invoke("2")
  wait(function()
    return #terminal.list() == 2 and vim.b.snacks_terminal.id == 2
  end)
  local second_buf = vim.api.nvim_get_current_buf()
  invoke("1")
  wait(function()
    return vim.api.nvim_get_current_buf() == first_buf
  end)
  local input = vim.ui.input
  vim.ui.input = function(_, callback)
    callback("50% done%f")
  end
  invoke("<A-r>")
  vim.ui.input = input
  local bar = vim.api.nvim_eval_statusline(
    terminal.render(),
    { winid = vim.api.nvim_get_current_win(), use_winbar = true, maxwidth = 200 }
  ).str
  check(bar:find("50% done%f", 1, true), "Terminal title interpreted percent escapes")
  terminal.hide()
  vim.cmd.tabnew()
  local tab = vim.api.nvim_get_current_tabpage()
  invoke("<C-\\>")
  wait(function()
    return vim.api.nvim_get_current_buf() == first_buf
  end)
  check(vim.api.nvim_get_current_tabpage() == tab, "Terminal switch changed workspace")
  terminal.close(2)
  wait(function()
    return not vim.api.nvim_buf_is_valid(second_buf)
  end)
  check(vim.api.nvim_buf_is_valid(first_buf), "Closing terminal 2 closed terminal 1")
  terminal.close(1)
  wait(function()
    return #terminal.list() == 0
  end)
end)

test("tabline displays literal percent in filenames", function()
  vim.cmd.enew({ bang = true })
  vim.api.nvim_buf_set_name(0, fixture .. "/audit%f.txt")
  local text = vim.api.nvim_eval_statusline(require("tabline").render(), { use_tabline = true, maxwidth = 300 }).str
  check(text:find("audit%f.txt", 1, true), "Tabline expanded filename format codes")
end)

test("context menu shortcut runs its action and restores source buffer", function()
  local source_buf = vim.api.nvim_get_current_buf()
  local selected = false
  require("config.context_menu").open_in_place_menu("Menu", {
    {
      text = "First",
      action = function()
        error("Wrong item selected")
      end,
    },
    {
      text = "Second",
      shortcut = "yd",
      action = function()
        check(vim.api.nvim_get_current_buf() == source_buf, "Menu action lost source buffer")
        selected = true
      end,
    },
  })
  local menu_buf = vim.api.nvim_get_current_buf()
  invoke("yd")
  wait(function()
    return selected
  end)
  check(not vim.api.nvim_buf_is_valid(menu_buf), "Menu buffer leaked")
end)

test("terminal creation reserves unique IDs before scheduled opens", function()
  local terminal = require("config.terminal")
  terminal.create()
  terminal.create()
  wait(function()
    return #terminal.list() == 2
  end)
  check(vim.deep_equal(terminal.list(), { 1, 2 }), "Rapid creation reused a terminal ID")
  terminal.close(1)
  terminal.close(2)
  wait(function()
    return #terminal.list() == 0
  end)
end)

test("input method events run asynchronously and in order", function()
  local system = vim.system
  local is_ascii = true
  local running, max_running = 0, 0
  vim.fn.executable = function(command)
    if command == "fcitx5-remote" or command == "busctl" then
      return 1
    end
    return executable(command)
  end
  vim.system = function(args, opts, callback)
    if args[1] ~= "busctl" and args[1] ~= "fcitx5-remote" then
      return system(args, opts, callback)
    end
    check(opts.timeout and opts.timeout <= 250, "Missing IPC timeout")
    running = running + 1
    max_running = math.max(max_running, running)
    vim.defer_fn(function()
      local output = ""
      if args[1] == "fcitx5-remote" then
        output = "rime\n"
      elseif args[7] == "IsAsciiMode" then
        output = "b " .. tostring(is_ascii) .. "\n"
      elseif args[7] == "SetAsciiMode" then
        is_ascii = args[9] == "true"
      end
      running = running - 1
      callback({ code = 0, stdout = output })
    end, 5)
    return {
      wait = function()
        error("Input method blocked on wait()")
      end,
      kill = function() end,
    }
  end
  require("fcitx").setup()
  vim.wait(60)
  is_ascii = false
  vim.api.nvim_exec_autocmds("InsertLeave", {})
  vim.api.nvim_exec_autocmds("InsertEnter", {})
  wait(function()
    return running == 0 and vim.b.saved_rime_chinese == true and is_ascii == false
  end)
  vim.api.nvim_exec_autocmds("InsertLeave", {})
  wait(function()
    return running == 0 and is_ascii
  end)
  vim.cmd.enew({ bang = true })
  vim.fn.jobstart({ "/bin/sh" }, { term = true })
  is_ascii = false
  vim.api.nvim_exec_autocmds("ModeChanged", { pattern = "t:nt" })
  vim.api.nvim_exec_autocmds("ModeChanged", { pattern = "nt:t" })
  wait(function()
    return running == 0 and vim.b.saved_rime_chinese == true and is_ascii == false
  end)
  vim.api.nvim_exec_autocmds("CmdlineLeave", {})
  wait(function()
    return running == 0 and is_ascii
  end)
  check(max_running == 1, "Input method commands raced")
  vim.system, vim.fn.executable = system, executable
end)

test("Neogit command and compatibility patches work with pinned revision", function()
  vim.cmd.enew({ bang = true })
  vim.cmd.tcd(repo)
  git(repo, { "checkout", "-qb", "side" })
  vim.fn.writefile({ "side" }, repo .. "/side.txt")
  git(repo, { "add", "." })
  git(repo, { "commit", "-qm", "Side" })
  git(repo, { "checkout", "-q", "main" })
  vim.fn.writefile({ "main" }, repo .. "/main.txt")
  git(repo, { "add", "." })
  git(repo, { "commit", "-qm", "Main" })
  git(repo, { "merge", "-q", "--no-ff", "side", "-m", "Merge" })
  vim.cmd("NeogitLogRefs HEAD")
  wait(function()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "NeogitLogView" then
        return true
      end
    end
    return false
  end, "Neogit graph command did not open a log")
  local view = require("neogit.buffers.commit_view").new(git(repo, { "rev-parse", "HEAD" }))
  check(view.commit_info and view.commit_overview, "Merge commit patch failed")
  local encoded = vim.inspect(view.commit_overview)
  check(encoded:find("side.txt", 1, true), "Merge overview did not compare first parent")
  view:open()
  view:update(git(repo, { "rev-parse", "HEAD" }))
  view:close()
end)

if #failures > 0 then
  print(table.concat(failures, "\n\n"))
  vim.cmd("cquit 1")
else
  print("All configuration regression checks passed")
  vim.cmd("qa!")
end
