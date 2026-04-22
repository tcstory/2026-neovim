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

function M.diff_current_file_last_change()
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

  local commit, commit_err = run_system({
    "git",
    "log",
    "-n",
    "1",
    "--format=%H",
    "--follow",
    "--",
    relative_path,
  }, git_root)

  if not commit then
    vim.notify("Failed to find last change for file: " .. commit_err, vim.log.levels.ERROR)
    return
  end

  if commit == "" then
    vim.notify("Current file has no git history", vim.log.levels.WARN)
    return
  end

  local parents, parents_err = run_system({ "git", "rev-list", "--parents", "-n", "1", commit }, git_root)
  if not parents then
    vim.notify("Failed to inspect commit parents: " .. parents_err, vim.log.levels.ERROR)
    return
  end

  local parent = vim.split(parents, " ", { trimempty = true })[2]
  if not parent then
    vim.notify("Last change is the root commit; no parent revision to compare", vim.log.levels.WARN)
    return
  end

  vim.cmd("CodeDiff file " .. parent .. " " .. commit)
end

return M
