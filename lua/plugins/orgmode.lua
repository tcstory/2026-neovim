return {
  {
    "nvim-orgmode/orgmode",
    event = "VeryLazy",
    ft = { "org" },
    config = function()
      require("orgmode").setup({
        org_agenda_files = {
          "~/Documents/next-decade/work/**/*",
          "~/Documents/next-decade/assets/**/*",
        },
        org_default_notes_file = "~/Documents/next-decade/work/projects/2026.org",

        -- 继承用户全局折叠设置 (foldlevel=99)，打开文件时不强制折叠大纲
        org_startup_folded = "inherit",

        -- 严格对齐 next-decade 的 TODO 规范（仅做静态识别与高亮）
        org_todo_keywords = {
          "TODO",
          "NEXT",
          "UAT",
          "GRAY",
          "|",
          "DONE",
          "CANCELED",
          "FINISHED",
        },

        -- 契合 Nord 配色系统的 TODO 高亮规则
        org_todo_keyword_faces = {
          TODO = ":foreground #BF616A :weight bold",      -- Nord Red (待排期)
          NEXT = ":foreground #88C0D0 :weight bold",      -- Nord Frost 蓝 (进行中)
          UAT = ":foreground #EBCB8B :weight bold",       -- Nord Yellow (提测中)
          GRAY = ":foreground #B48EAD :weight bold",      -- Nord Purple (灰度观察)
          DONE = ":foreground #A3BE8C :weight bold",      -- Nord Green (已上线/完成)
          FINISHED = ":foreground #8FBCBB :weight bold",  -- Nord Teal (历史完成)
          CANCELED = ":foreground #4C566A :slant italic", -- Nord Muted (已取消)
        },

        -- 隐藏加粗、斜体等字符标记 (*bold* -> bold)
        org_hide_emphasis_markers = true,

        mappings = {
          org = {
            org_open_at_point = "<CR>", -- 回车直接跳转链接
            org_todo = false,           -- 禁用在 buffer 内直接改写 TODO 状态，防误触
            org_todo_prev = false,
          },
        },
      })

      -- Buffer 局部设置（只对 org 文件生效）
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "org",
        callback = function(ev)
          -- 启用局部隐藏语法：将 [[file:...][说明]] 渲染为干净的“说明”
          vim.opt_local.conceallevel = 2
          vim.opt_local.concealcursor = "nc"
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true

          -- 仅在 org 局部绑定复选框切换 (- [ ] <-> - [X])
          vim.keymap.set("n", "<leader>cc", "<cmd>lua require('orgmode').action('org_mappings.toggle_checkbox')<CR>", {
            buffer = ev.buf,
            silent = true,
            desc = "Toggle Subtask Checkbox",
          })
        end,
      })
    end,
  },
}
