return {
  "NeogitOrg/neogit",
  lazy = true,
  commit = require("config.neogit_compat").commit,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "tcstory/diffview-plus.nvim",
    "folke/snacks.nvim",
  },
  cmd = { "Neogit", "NeogitLogRefs" },
  keys = {
    { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" },
    { "<leader>gL", ":NeogitLogRefs ", desc = "Neogit log selected refs" },
  },
  opts = {
    graph_style = "unicode",
    integrations = {
      diffview = true,
      codediff = false,
      snacks = true,
    },
    diff_viewer = "diffview",
  },
  config = function(_, opts)
    require("config.neogit").setup(opts)
  end,
}
