return {
  "NeogitOrg/neogit",
  lazy = true,
  dependencies = {
    "nvim-lua/plenary.nvim",         -- required

    -- Only one of these is needed.
    "esmuellert/codediff.nvim",      -- optional

    -- For a custom log pager
    "m00qek/baleia.nvim",            -- optional

    -- Only one of these is needed.
    "folke/snacks.nvim",             -- optional
  },
  cmd = "Neogit",
  keys = {
    { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" }
  },
  opts = {
    graph_style = "unicode",
    integrations = {
      codediff = true,
      snacks = true,
    },
    diff_viewer = "codediff",
  },
  config = function(_, opts)
    require("neogit").setup(opts)
  end,
}
