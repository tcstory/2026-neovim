local M = {}

local function run_system(cmd, cwd)
  local output, err = require("config.process").run(cmd, cwd)
  if not output then
    return nil, err
  end
  return (output:gsub("[\r\n]+$", ""))
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

function M.open_rebased()
  local target_dir = nil
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname ~= "" then
    local dir = vim.fn.fnamemodify(bufname, ":h")
    target_dir = run_system({ "git", "rev-parse", "--show-toplevel" }, dir)
  end

  if not target_dir or target_dir == "" then
    local cwd = M.tab_or_global_cwd()
    target_dir = run_system({ "git", "rev-parse", "--show-toplevel" }, cwd) or cwd
  end

  local rebased_bin = vim.fn.exepath("rebased")
  if rebased_bin == "" then
    rebased_bin = vim.fn.expand("~/Documents/Rebased-x86_64.AppImage")
  end

  if vim.fn.filereadable(rebased_bin) == 0 and vim.fn.executable(rebased_bin) == 0 then
    vim.notify("Rebased binary not found: " .. rebased_bin, vim.log.levels.ERROR)
    return
  end

  vim.system({ rebased_bin, target_dir }, { detach = true })
  vim.notify("Opening Rebased: " .. target_dir, vim.log.levels.INFO)
end

return M
