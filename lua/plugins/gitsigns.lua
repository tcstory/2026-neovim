return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPre", "BufNewFile" },
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "gitsigns-blame",
      callback = function(ev)
        local utils = require("utils")
        vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = ev.buf, silent = true, nowait = true, desc = "Close Git Blame" })
        vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = ev.buf, silent = true, nowait = true, desc = "Close Git Blame" })

        -- 回车直接在 Git Graph 中定位当前行提交
        vim.keymap.set("n", "<CR>", function()
          local lnum = vim.api.nvim_win_get_cursor(0)[1]
          local info = utils.get_blame_commit_at_line(vim.api.nvim_get_current_win(), lnum)
          if info and info.sha and not info.is_uncommitted then
            utils.show_commit_in_graph(info.sha)
          end
        end, { buffer = ev.buf, silent = true, nowait = true, desc = "Show in Git Graph" })

        -- 双击左键直接在 Git Graph 中定位
        vim.keymap.set("n", "<2-LeftMouse>", function()
          local m = vim.fn.getmousepos()
          local lnum = (m.line and m.line > 0) and m.line or vim.api.nvim_win_get_cursor(0)[1]
          local info = utils.get_blame_commit_at_line(vim.api.nvim_get_current_win(), lnum)
          if info and info.sha and not info.is_uncommitted then
            utils.show_commit_in_graph(info.sha)
          end
        end, { buffer = ev.buf, silent = true, nowait = true, desc = "Show in Git Graph" })

        -- 按 d 查看此 Commit 完整 Diff
        vim.keymap.set("n", "d", function()
          local lnum = vim.api.nvim_win_get_cursor(0)[1]
          local info = utils.get_blame_commit_at_line(vim.api.nvim_get_current_win(), lnum)
          if info and info.sha and not info.is_uncommitted then
            utils.show_commit_diff(info.sha)
          end
        end, { buffer = ev.buf, silent = true, nowait = true, desc = "Show Commit Diff" })

        -- 按 y 复制 Commit Hash
        vim.keymap.set("n", "y", function()
          local lnum = vim.api.nvim_win_get_cursor(0)[1]
          local info = utils.get_blame_commit_at_line(vim.api.nvim_get_current_win(), lnum)
          if info and info.sha and not info.is_uncommitted then
            vim.fn.setreg("+", info.sha)
            vim.notify("已复制 Commit Hash: " .. info.sha)
          end
        end, { buffer = ev.buf, silent = true, nowait = true, desc = "Yank Commit Hash" })
      end,
    })
  end,
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
