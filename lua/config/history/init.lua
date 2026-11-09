local M = {}

function M.setup()
  -- 沿用原目录，保留已有撤销历史；历史记录不负责保存源文件。
  local directory = vim.fn.stdpath("state") .. "/local-history-undo"
  vim.fn.mkdir(directory, "p")
  vim.opt.undofile = true
  vim.opt.undodir = directory
  vim.api.nvim_create_user_command("LocalHistoryCheck", function()
    Snacks.picker.undo()
  end, { desc = "Browse undo history", force = true })
end

return M
