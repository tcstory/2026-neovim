return {
  name = "native-tabline",
  dir = vim.fn.stdpath("config") .. "/lua/tabline",
  event = "VeryLazy",
  keys = {
    { "<leader>ta", "<cmd>tabnew<cr>", desc = "New Tab (Workspace)" },
    { "<leader>to", "<cmd>tabonly<cr>", desc = "Close Other Tabs" },
  },
  config = function()
    require("tabline").setup({
      showtabline = 1,
    })
  end,
}
