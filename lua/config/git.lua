local M = {}
local utils = require("utils")
local run_system = require("config.process").run
local snapshots = {}

function M.cleanup_snapshots()
  for path, tab in pairs(snapshots) do
    if not vim.api.nvim_tabpage_is_valid(tab) then
      vim.fn.delete(path)
      snapshots[path] = nil
    end
  end
end

function M.diff_current_file()
  local file = utils.current_file()
  if not file or vim.bo.buftype ~= "" then
    return
  end
  local root, root_error = utils.git_root(file)
  if not root then
    vim.notify("Not in a git repository: " .. root_error, vim.log.levels.WARN)
    return
  end
  local relative = vim.fs.relpath(root, file)
  if not relative then
    return
  end
  local head, err = run_system({ "git", "show", "HEAD:" .. relative }, root)
  if not head then
    vim.notify("Failed to read file content from HEAD: " .. err, vim.log.levels.ERROR)
    return
  end
  local separator = vim.bo.fileformat == "dos" and "\r\n" or (vim.bo.fileformat == "mac" and "\r" or "\n")
  local current = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), separator)
  if vim.bo.endofline then
    current = current .. separator
  end
  if vim.bo.bomb and vim.bo.fileencoding == "utf-8" then
    current = "\239\187\191" .. current
  end
  if head == current then
    vim.notify("Current buffer has no changes against HEAD", vim.log.levels.INFO)
    return
  end
  if head:find("\0", 1, true) then
    vim.notify("Diff This only supports text files", vim.log.levels.WARN)
    return
  end
  -- Diffview 复用右侧原 buffer，因此不需要保存，也不会丢失未保存的改动。
  require("lazy").load({ plugins = { "diffview-plus.nvim" } })
  local temp_file = vim.fn.tempname() .. "-HEAD-" .. vim.fs.basename(file)
  vim.fn.writefile(vim.split(head, "\n", { plain = true }), temp_file, "b")
  local source_tab = vim.api.nvim_get_current_tabpage()
  local ok, open_error =
    pcall(vim.cmd, "DiffviewDiffFiles " .. vim.fn.fnameescape(temp_file) .. " " .. vim.fn.fnameescape(file))
  if not ok or vim.api.nvim_get_current_tabpage() == source_tab then
    vim.fn.delete(temp_file)
    vim.notify(tostring(open_error or "Diffview could not open the file comparison"), vim.log.levels.ERROR)
    return
  end
  snapshots[temp_file] = vim.api.nvim_get_current_tabpage()
  local group = vim.api.nvim_create_augroup("tcstory_diff_snapshots", { clear = true })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = group,
    callback = function()
      vim.schedule(M.cleanup_snapshots)
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      for path in pairs(snapshots) do
        vim.fn.delete(path)
      end
    end,
  })
end

-- Gitsigns 的 buffer URI 唯一标识仓库、版本和文件，不能凭窗口顺序猜源文件。
function M.get_blame_commit_at_line(win, line)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return nil
  end
  local buf = vim.api.nvim_win_get_buf(win)
  line = line and line > 0 and line or vim.api.nvim_win_get_cursor(win)[1]
  local name = vim.api.nvim_buf_get_name(buf)
  local ok, gs = pcall(require, "gitsigns.cache")
  local matched
  if ok and type(gs.cache) == "table" then
    for source, entry in pairs(gs.cache) do
      if type(entry.get_rev_bufname) == "function" then
        local valid, uri = pcall(entry.get_rev_bufname, entry)
        if valid and type(uri) == "string" and uri:gsub("^gitsigns:", "gitsigns-blame:") == name then
          matched = entry
          vim.b[buf].tcstory_blame_source = { buf = source, file = entry.file }
          break
        end
      end
    end
  end
  local source = vim.b[buf].tcstory_blame_source
  local file = source and source.file
  local root = file and utils.git_root(file)
  if not root then
    vim.notify("Cannot identify the source repository for this Git Blame window", vim.log.levels.WARN)
    return nil
  end
  local entries = matched and matched.blame and matched.blame.entries
  local entry = entries and entries[line]
  local commit = entry and entry.commit
  if commit then
    local sha = commit.sha or ""
    return {
      sha = sha,
      abbrev_sha = commit.abbrev_sha or sha:sub(1, 7),
      author = commit.author or "",
      summary = commit.summary or "",
      is_uncommitted = sha == "" or sha:match("^0+$") ~= nil,
      file = file,
      cwd = root,
    }
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, line, false)
  for i = #lines, 1, -1 do
    local sha = lines[i]:match("^[^%w]*(%x+)%f[%X]")
    if sha and #sha >= 7 and #sha <= 40 then
      return {
        sha = sha,
        abbrev_sha = sha:sub(1, 7),
        author = "",
        summary = "",
        is_uncommitted = sha:match("^0+$") ~= nil,
        file = file,
        cwd = root,
      }
    end
  end
  vim.notify("No commit hash found at this Git Blame line", vim.log.levels.WARN)
end

function M.show_commit_in_graph(target_sha, cwd)
  if not target_sha or target_sha == "" then
    vim.notify("未找到有效的提交 Hash", vim.log.levels.WARN)
    return
  end

  local clean_sha = target_sha
  if not clean_sha:match("^%x+$") then
    return
  end
  cwd = cwd or utils.git_root()
  if not cwd then
    return
  end
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
  local res = vim
    .system({ "git", "rev-list", "--ancestry-path", clean_sha .. "..HEAD" }, { cwd = cwd, text = true, timeout = 5000 })
    :wait()
  if res.code == 0 and res.stdout and res.stdout ~= "" then
    local descendants = vim.split(vim.trim(res.stdout), "\n", { plain = true })
    if #descendants > 0 then
      -- 取目标提交之后约 15~20 个提交作为头部锚点（rev-list 倒序排列，末尾是最邻近的直接子提交）
      local idx = math.max(1, #descendants - 15)
      anchor_ref = descendants[idx]
    end
  end

  -- 打开包含上下文的 Git 图谱
  require("neogit.lib.git.repository").instance(cwd)
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

function M.show_commit_diff(sha, cwd)
  if not sha or not sha:match("^%x+$") or sha:match("^0+$") then
    vim.notify("未找到有效的提交 Hash", vim.log.levels.WARN)
    return
  end
  cwd = cwd or utils.git_root()
  if not cwd then
    return
  end
  require("lazy").load({ plugins = { "diffview-plus.nvim" } })
  vim.cmd("DiffviewOpen -C=" .. vim.fn.fnameescape(cwd) .. " " .. sha .. "^!")
  vim.notify("正在查看提交 " .. sha:sub(1, 7) .. " 的完整改动", vim.log.levels.INFO)
end

return M
