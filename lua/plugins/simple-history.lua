return {
  dir = vim.fn.stdpath("config") .. "/lua/config/history",
  name = "native-history",
  lazy = false,
  config = function()
    require("config.history").setup()
  end,
  keys = {
    { "<leader>su", "<cmd>LocalHistoryCheck<cr>", desc = "Undo History" },
  },
}
