local M = {}

function M.strip_ansi(str)
  str = str:gsub("\27%]8;;[^\27\7]*[\27\7]\27?\\?", "")
  str = str:gsub("\27%[[0-9;]*[a-zA-Z]", "")
  return str
end

function M.find_file_in_text(text, cwd)
  text = M.strip_ansi(text)
  text = text:gsub("vscode://file", ""):gsub("file://", "")
  local candidates = {}
  -- 匹配 路径:行号(:列号)
  for p, l in text:gmatch("([%a%d%-_./]+%.[%a%d]+):(%d+)") do
    local full = p
    if not vim.startswith(full, "/") and not vim.startswith(full, "~") then
      full = vim.fs.normalize((cwd or vim.fn.getcwd()) .. "/" .. full)
    end
    if vim.uv.fs_stat(full) then
      table.insert(candidates, { path = full, line = tonumber(l) })
    end
  end
  if #candidates == 0 then
    -- 匹配纯路径
    for p in text:gmatch("([%a%d%-_./]+%.[%a%d]+)") do
      local full = p
      if not vim.startswith(full, "/") and not vim.startswith(full, "~") then
        full = vim.fs.normalize((cwd or vim.fn.getcwd()) .. "/" .. full)
      end
      if vim.uv.fs_stat(full) then
        table.insert(candidates, { path = full, line = 1 })
      end
    end
  end
  return candidates[1]
end

function M.jump_to_terminal_target(self, target)
  if not target or not target.path then
    return false
  end
  self:hide()
  vim.schedule(function()
    vim.cmd(string.format("edit +%d %s", target.line or 1, vim.fn.fnameescape(target.path)))
    vim.cmd("normal! zvzz")
    vim.notify(
      string.format("已定位至: %s:%d", vim.fn.fnamemodify(target.path, ":."), target.line or 1),
      vim.log.levels.INFO
    )
  end)
  return true
end

function M.try_jump_from_mouse(self)
  local mouse = vim.fn.getmousepos()
  if not mouse or mouse.winid == 0 or mouse.winid ~= self.win or mouse.line <= 0 then
    return false
  end
  local bufnr = vim.api.nvim_win_get_buf(mouse.winid)
  local line_num = mouse.line
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if not lines or #lines == 0 then
    return false
  end
  local info = self.buf and vim.b[self.buf].snacks_terminal
  local target = M.find_file_in_text(lines[1], info and info.cwd)
  if target then
    return M.jump_to_terminal_target(self, target)
  end
  return false
end

function M.try_jump_from_cursor(self)
  local bufnr = self.buf or vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line_num = cursor[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
  if not lines or #lines == 0 then
    return false
  end
  local info = self.buf and vim.b[self.buf].snacks_terminal
  local target = M.find_file_in_text(lines[1], info and info.cwd)
  if target then
    return M.jump_to_terminal_target(self, target)
  end
  return false
end

return M
