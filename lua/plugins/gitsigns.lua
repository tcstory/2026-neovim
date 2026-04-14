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
        require("gitsigns").diffthis()
      end,
      desc = "Diff This",
    },
    {
      "<leader>gD",
      function()
        local current_tab = vim.api.nvim_get_current_tabpage()
        local current_buf = vim.api.nvim_get_current_buf()
        local current_name = vim.api.nvim_buf_get_name(current_buf)
        local diff_wins = {}

        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(current_tab)) do
          if vim.wo[win].diff then
            diff_wins[#diff_wins + 1] = win
          end
        end

        if #diff_wins == 0 then
          return
        end

        for _, win in ipairs(diff_wins) do
          if vim.api.nvim_win_is_valid(win) then
            pcall(vim.api.nvim_win_call, win, function()
              vim.cmd("diffoff")
            end)
          end
        end

        for _, win in ipairs(diff_wins) do
          if vim.api.nvim_win_is_valid(win) then
            local buf = vim.api.nvim_win_get_buf(win)
            local name = vim.api.nvim_buf_get_name(buf)

            if buf ~= current_buf and name ~= current_name then
              pcall(vim.api.nvim_win_close, win, true)
            end
          end
        end
      end,
      desc = "Close Diff View",
    },
  },
}
