return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = {
      { "g", group = "Goto" },
      { "<leader>", group = "Leader" },
      { "<leader>b", group = "Buffer" },
      { "<leader>c", group = "Code" },
      { "<leader>f", group = "Find" },
      { "<leader>g", group = "Git" },
      { "<leader>n", group = "Notify" },
      { "<leader>q", group = "Quit" },
      { "<leader>r", group = "Rename" },
      { "<leader>s", group = "Search" },
      { "<leader>t", group = "Tabs" },
      { "<leader>w", group = "Windows" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
