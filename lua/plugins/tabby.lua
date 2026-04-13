return {
  "nanozuki/tabby.nvim",
  event = "VimEnter",
  keys = {
    { "<leader>tn", "<cmd>tabnew<cr>", desc = "New Tab" },
    { "<leader>tq", "<cmd>tabclose<cr>", desc = "Close Tab" },
    { "<leader>th", "<cmd>tabprevious<cr>", desc = "Prev Tab" },
    { "<leader>tl", "<cmd>tabnext<cr>", desc = "Next Tab" },
    { "<leader>to", "<cmd>tabonly<cr>", desc = "Only Tab" },
    { "<leader>tj", "<cmd>Tabby pick_window<cr>", desc = "Pick Window" },
  },
  config = function()
    vim.o.showtabline = 2

    local theme = {
      fill = "TabLineFill",
      head = "TabLine",
      current = "TabLineSel",
      tab = "TabLine",
      tail = "TabLine",
    }

    require("tabby").setup({
      line = function(line)
        local cwd = vim.fn.fnamemodify(vim.fn.getcwd(-1, 0), ":t")
        if cwd == "" then
          cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
        end

        return {
          {
            { " tabs ", hl = theme.head },
            hl = theme.head,
          },
          line.tabs().foreach(function(tab)
            local hl = tab.is_current() and theme.current or theme.tab
            local win = tab.current_win()
            local buf = win.buf()
            local title = tab.name()

            if title == "" then
              title = win.buf_name()
            end

            return {
              " ",
              tab.in_jump_mode() and tab.jump_key() or tab.number(),
              " ",
              title,
              buf.is_changed() and " ●" or "",
              " ",
              hl = hl,
              margin = " ",
            }
          end),
          line.spacer(),
          {
            " " .. cwd .. " ",
            hl = theme.tail,
          },
          hl = theme.fill,
        }
      end,
    })
  end,
}
