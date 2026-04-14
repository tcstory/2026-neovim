local M = {}

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

function M.copy_current_file_path_from_tcd()
  local path, is_relative = M.current_file_path_from_tcd()

  if not path then
    return
  end

  M.copy_to_clipboard(path)

  if is_relative then
    vim.notify("Copied path: " .. path, vim.log.levels.INFO)
  else
    vim.notify("File is outside tcd, copied absolute path: " .. path, vim.log.levels.WARN)
  end
end

function M.copy_current_file_dir_from_tcd()
  local path, is_relative = M.current_file_dir_from_tcd()

  if not path then
    return
  end

  M.copy_to_clipboard(path)

  if is_relative then
    vim.notify("Copied directory: " .. path, vim.log.levels.INFO)
  else
    vim.notify("Directory is outside tcd, copied absolute path: " .. path, vim.log.levels.WARN)
  end
end

return M
