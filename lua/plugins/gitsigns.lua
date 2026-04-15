return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {},
  keys = {
    {
      "]c",
      function()
        local gitsigns = require("gitsigns")
        local current_tab = vim.api.nvim_get_current_tabpage()

        if vim.b.gitsigns_head then
          gitsigns.nav_hunk("next", { navigation_message = true, target = "all" })
          return
        end

        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(current_tab)) do
          local buf = vim.api.nvim_win_get_buf(win)

          if vim.bo[buf].buftype == "" and vim.b[buf].gitsigns_head then
            vim.api.nvim_set_current_win(win)
            gitsigns.nav_hunk("next", { navigation_message = true, target = "all" })
            return
          end
        end

        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        end
      end,
      desc = "Next Hunk",
    },
    {
      "[c",
      function()
        local gitsigns = require("gitsigns")
        local current_tab = vim.api.nvim_get_current_tabpage()

        if vim.b.gitsigns_head then
          gitsigns.nav_hunk("prev", { navigation_message = true, target = "all" })
          return
        end

        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(current_tab)) do
          local buf = vim.api.nvim_win_get_buf(win)

          if vim.bo[buf].buftype == "" and vim.b[buf].gitsigns_head then
            vim.api.nvim_set_current_win(win)
            gitsigns.nav_hunk("prev", { navigation_message = true, target = "all" })
            return
          end
        end

        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        end
      end,
      desc = "Prev Hunk",
    },
    {
      "<leader>gp",
      function()
        require("gitsigns").preview_hunk()
      end,
      desc = "Preview Hunk",
    },
    {
      "<leader>gd",
      function()
        require("utils").diff_current_file()
      end,
      desc = "Diff This",
    },
  },
}
