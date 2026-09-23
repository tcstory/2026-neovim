local M = {}

local function run_system(cmd, cwd)
  local result = vim.system(cmd, { cwd = cwd, text = true }):wait()

  if result.code ~= 0 then
    local err = (result.stderr or ""):gsub("%s+$", "")
    if err == "" then
      err = table.concat(cmd, " ")
    end
    return nil, err
  end

  return (result.stdout or ""):gsub("%s+$", "")
end

function M.tab_or_global_cwd()
  local tab_cwd = vim.fn.getcwd(-1, 0)
  local global_cwd = vim.fn.getcwd(-1, -1)

  if tab_cwd ~= global_cwd then
    return tab_cwd
  end

  return global_cwd
end

local function current_file()
  local file = vim.api.nvim_buf_get_name(0)

  if file == "" then
    vim.notify("Current buffer has no file path", vim.log.levels.WARN)
    return nil
  end

  return file
end

function M.current_file()
  return current_file()
end

function M.git_root(path)
  local target = path or current_file()

  if not target then
    return nil
  end

  local cwd = vim.fn.fnamemodify(target, ":h")
  return run_system({ "git", "rev-parse", "--show-toplevel" }, cwd)
end

function M.path_from_tcd(path)
  local cwd = M.tab_or_global_cwd()
  local relative = vim.fs.relpath(cwd, path)

  return relative or path, relative ~= nil
end

function M.current_file_path_from_tcd()
  local file = current_file()

  if not file then
    return nil, false
  end

  return M.path_from_tcd(file)
end

function M.current_file_dir_from_tcd()
  local file = current_file()

  if not file then
    return nil, false
  end

  return M.path_from_tcd(vim.fs.dirname(file))
end

function M.copy_to_clipboard(value)
  vim.fn.setreg("+", value)
  vim.fn.setreg('"', value)
end

local function notify_copied_path(kind, path, is_relative)
  if is_relative then
    vim.notify("Copied " .. kind .. ": " .. path, vim.log.levels.INFO)
  else
    vim.notify(kind:gsub("^%l", string.upper) .. " is outside tcd, copied absolute path: " .. path, vim.log.levels.WARN)
  end
end

function M.copy_path_from_tcd(path)
  if not path or path == "" then
    vim.notify("No path to copy", vim.log.levels.WARN)
    return
  end

  local value, is_relative = M.path_from_tcd(path)
  M.copy_to_clipboard(value)
  notify_copied_path("path", value, is_relative)
end

function M.copy_dir_from_tcd(path)
  if not path or path == "" then
    vim.notify("No directory to copy", vim.log.levels.WARN)
    return
  end

  local target = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  local value, is_relative = M.path_from_tcd(target)
  M.copy_to_clipboard(value)
  notify_copied_path("directory", value, is_relative)
end

function M.copy_current_file_path_from_tcd()
  local path, is_relative = M.current_file_path_from_tcd()

  if not path then
    return
  end

  M.copy_to_clipboard(path)
  notify_copied_path("path", path, is_relative)
end

function M.copy_current_file_dir_from_tcd()
  local path, is_relative = M.current_file_dir_from_tcd()

  if not path then
    return
  end

  M.copy_to_clipboard(path)
  notify_copied_path("directory", path, is_relative)
end

function M.diff_current_file()
  local file = current_file()

  if not file then
    return
  end

  local git_root, git_root_err = M.git_root(file)
  if not git_root then
    vim.notify("Not in a git repository: " .. git_root_err, vim.log.levels.WARN)
    return
  end

  local relative_path = vim.fs.relpath(git_root, file)
  if not relative_path then
    vim.notify("Failed to compute git-relative path for current file", vim.log.levels.ERROR)
    return
  end

  local diff_output, diff_err = run_system({
    "git",
    "diff",
    "--name-only",
    "HEAD",
    "--",
    relative_path,
  }, git_root)

  if diff_output == nil then
    vim.notify("Failed to inspect file diff against HEAD: " .. diff_err, vim.log.levels.ERROR)
    return
  end

  if diff_output == "" then
    vim.notify("Current file has no changes against HEAD", vim.log.levels.INFO)
    return
  end

  local head_content, head_err = run_system({
    "git",
    "show",
    "HEAD:" .. relative_path,
  }, git_root)

  if head_content == nil then
    vim.notify("Failed to read file content from HEAD: " .. head_err, vim.log.levels.ERROR)
    return
  end

  local temp_file = vim.fn.tempname()
  local lines = vim.split(head_content, "\n", { plain = true })
  vim.fn.writefile(lines, temp_file)
  vim.cmd("CodeDiff file " .. vim.fn.fnameescape(temp_file) .. " " .. vim.fn.fnameescape(file))
end

function M.get_blame_commit_at_line(blm_win, lnum)
  if not blm_win or not vim.api.nvim_win_is_valid(blm_win) then
    return nil
  end

  local line = lnum
  if not line or line <= 0 then
    line = vim.api.nvim_win_get_cursor(blm_win)[1]
  end

  -- 1. 尝试从同一个 Tab 的主编辑区 Buffer 的 Gitsigns Cache 中读取精准 Blame 记录
  local cur_tab = vim.api.nvim_win_get_tabpage(blm_win)
  local main_buf = nil
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(cur_tab)) do
    if w ~= blm_win and vim.api.nvim_win_is_valid(w) then
      local b = vim.api.nvim_win_get_buf(w)
      if vim.bo[b].filetype ~= "gitsigns-blame" and vim.bo[b].buftype == "" then
        main_buf = b
        break
      end
    end
  end

  local ok_cache, gitsigns_cache = pcall(require, "gitsigns.cache")
  local cache = ok_cache and gitsigns_cache.cache
  local bcache = (cache and main_buf) and cache[main_buf]

  if not (bcache and bcache.blame and bcache.blame.entries) and cache then
    for _, c in pairs(cache) do
      if c.blame and c.blame.entries then
        bcache = c
        break
      end
    end
  end

  if bcache and bcache.blame and bcache.blame.entries then
    local entry = bcache.blame.entries[line]
    if entry and entry.commit then
      local sha = entry.commit.sha or ""
      return {
        sha = sha,
        abbrev_sha = entry.commit.abbrev_sha or sha:sub(1, 7),
        author = entry.commit.author or "",
        summary = entry.commit.summary or "",
        is_uncommitted = (sha == "" or sha:match("^0+$") ~= nil),
        file = bcache.file,
      }
    end
  end

  -- 2. Fallback: 直接从 blame 缓冲区文本中正则扫描短 Commit Hash
  local blm_buf = vim.api.nvim_win_get_buf(blm_win)
  if vim.api.nvim_buf_is_valid(blm_buf) then
    local lines = vim.api.nvim_buf_get_lines(blm_buf, 0, -1, false)
    for i = line, 1, -1 do
      local text = lines[i]
      if text then
        local sha = text:match("%s([0-9a-fA-F]{7,40})%s") or text:match("^[^%w]*([0-9a-fA-F]{7,40})")
        if sha then
          return {
            sha = sha,
            abbrev_sha = sha:sub(1, 7),
            author = "",
            summary = "",
            is_uncommitted = (sha:match("^0+$") ~= nil),
          }
        end
      end
    end
  end

  return nil
end

function M.show_commit_in_graph(target_sha)
  if not target_sha or target_sha == "" then
    vim.notify("未找到有效的提交 Hash", vim.log.levels.WARN)
    return
  end

  local clean_sha = target_sha:gsub("[^0-9a-fA-F]", "")
  if clean_sha == "" or clean_sha:match("^0+$") then
    vim.notify("无效的提交 Hash", vim.log.levels.WARN)
    return
  end

  local short_sha = clean_sha:sub(1, 7)
  local ok, neogit = pcall(require, "neogit")
  if not ok then
    vim.notify("Neogit 插件未加载", vim.log.levels.ERROR)
    return
  end

  -- 计算智能锚点，确保即使目标提交距离 HEAD 较远，也能在 Git 图谱中完整展示其前后的提交
  local anchor_ref = clean_sha
  local res = vim.system({ "git", "rev-list", "--ancestry-path", clean_sha .. "..HEAD" }, { text = true }):wait()
  if res.code == 0 and res.stdout and res.stdout ~= "" then
    local descendants = vim.split(vim.trim(res.stdout), "\n", { plain = true })
    if #descendants > 0 then
      -- 取目标提交之后约 15~20 个提交作为头部锚点（rev-list 倒序排列，末尾是最邻近的直接子提交）
      local idx = math.max(1, #descendants - 15)
      anchor_ref = descendants[idx]
    end
  end

  -- 打开包含上下文的 Git 图谱
  neogit.action("log", "log_current", { anchor_ref, "--graph", "--color", "--decorate" })()

  -- 轮询等待图谱窗口渲染就绪，精准跳转定位到该 Commit
  local retries = 0
  local function try_jump()
    retries = retries + 1
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_is_valid(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "NeogitLogView" then
          local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
          for idx, l in ipairs(lines) do
            if l:find(short_sha, 1, true) then
              vim.api.nvim_set_current_win(win)
              vim.api.nvim_win_set_cursor(win, { idx, 0 })
              vim.cmd("normal! zz")
              pcall(function()
                local ns = vim.api.nvim_create_namespace("neogit_jump_hl")
                vim.hl.range(buf, ns, "Visual", { idx - 1, 0 }, { idx - 1, -1 }, { timeout = 1500 })
              end)
              vim.notify("已在 Git Graph 中定位到提交: " .. short_sha, vim.log.levels.INFO)
              return
            end
          end
        end
      end
    end

    if retries < 25 then
      vim.defer_fn(try_jump, 50)
    else
      vim.notify("在 Git Graph 中未找到提交: " .. short_sha, vim.log.levels.WARN)
    end
  end

  vim.defer_fn(try_jump, 60)
end

function M.show_commit_diff(target_sha)
  if not target_sha or target_sha == "" or target_sha:match("^0+$") then
    vim.notify("未找到有效的提交 Hash", vim.log.levels.WARN)
    return
  end

  local short_sha = target_sha:sub(1, 7)
  vim.cmd("DiffviewOpen " .. target_sha .. "^!")
  vim.notify("正在查看提交 " .. short_sha .. " 的完整改动", vim.log.levels.INFO)
end

local active_menu_close = nil

function M.cancel_active_inputs()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "snacks_input" then
        vim.api.nvim_win_call(win, function()
          vim.cmd("stopinsert")
          vim.cmd("normal q")
        end)
      end
    end
  end
end

function M.open_in_place_menu(title, items)
  if active_menu_close then
    pcall(active_menu_close)
    active_menu_close = nil
  end

  M.cancel_active_inputs()

  local mouse = vim.fn.getmousepos()
  local lines = {}
  local shortcuts = {}
  local has_any_shortcut = false

  for _, item in ipairs(items) do
    local sc = item.shortcut or item.rtxt
    if sc and sc ~= "" then
      has_any_shortcut = true
      break
    end
  end

  local max_left = 0
  local max_sc = 0
  if has_any_shortcut then
    for _, item in ipairs(items) do
      local label = item.text or item.name or ""
      local sc = item.shortcut or item.rtxt or ""
      max_left = math.max(max_left, vim.fn.strdisplaywidth(label))
      max_sc = math.max(max_sc, vim.fn.strdisplaywidth(sc))
    end
  end

  local max_width = (title and title ~= "") and (vim.fn.strdisplaywidth(title) + 4) or 10

  for _, item in ipairs(items) do
    local label = item.text or item.name or ""
    local text
    local sc_info = nil
    if has_any_shortcut then
      local sc = item.shortcut or item.rtxt or ""
      local spaces = string.rep(" ", max_left - vim.fn.strdisplaywidth(label) + 3)
      local prefix = "  " .. label .. spaces
      text = prefix .. sc .. "  "
      if sc ~= "" then
        sc_info = { start_col = #prefix, end_col = #prefix + #sc }
      end
    else
      text = "  " .. label .. "  "
    end
    table.insert(lines, text)
    table.insert(shortcuts, sc_info)
    max_width = math.max(max_width, vim.fn.strdisplaywidth(text))
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "native_context_menu"

  local ns_id = vim.api.nvim_create_namespace("native_context_menu")
  for idx, sc_info in ipairs(shortcuts) do
    if sc_info then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, idx - 1, sc_info.start_col, {
        end_col = sc_info.end_col,
        hl_group = "Comment",
      })
    end
  end

  local height = #lines
  local width = max_width
  local row = 0
  local col = 1
  local relative = "mouse"

  if not mouse.screenrow or mouse.screenrow == 0 then
    relative = "cursor"
    row = 1
    col = 0
  else
    if mouse.screenrow + height + 2 > vim.o.lines then
      row = -height - 1
    end
    if mouse.screencol and mouse.screencol + width + 2 > vim.o.columns then
      col = -width
    end
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = relative,
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = (title and title ~= "") and (" " .. title .. " ") or nil,
    title_pos = "center",
  })

  vim.wo[win].cursorline = true
  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual"

  local closed = false
  local function close_menu()
    if closed then
      return
    end
    closed = true
    if active_menu_close == close_menu then
      active_menu_close = nil
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  active_menu_close = close_menu

  local function select_index(idx)
    if idx >= 1 and idx <= #items then
      local choice = items[idx]
      close_menu()
      local act = choice.action or choice.cmd
      if act then
        if type(act) == "function" then
          vim.schedule(act)
        elseif type(act) == "string" then
          vim.schedule(function()
            vim.cmd(act)
          end)
        end
      end
    end
  end

  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    select_index(cursor[1])
  end, { buffer = buf, silent = true, nowait = true })

  vim.keymap.set("n", "<LeftMouse>", function()
    local m = vim.fn.getmousepos()
    if m.winid == win then
      select_index(m.line)
    else
      close_menu()
    end
  end, { buffer = buf, silent = true, nowait = true })

  vim.keymap.set("n", "<RightMouse>", close_menu, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close_menu, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "q", close_menu, { buffer = buf, silent = true, nowait = true })

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = close_menu,
  })

  return close_menu
end

return M
