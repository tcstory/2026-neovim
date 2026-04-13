return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    dashboard = { enabled = true },
    explorer = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    picker = { enabled = true },
    quickfile = { enabled = true },
    scope = { enabled = true },
    scroll = { enabled = true },
    statuscolumn = { enabled = true },
    terminal = {
      interactive = true,
      start_insert = true,
      auto_insert = true,
      win = {
        style = "float",
        position = "float",
        border = "rounded",
        title = " Terminal ",
        title_pos = "center",
        width = 0.85,
        height = 0.8,
        backdrop = 60,
        keys = {
          term_hide = {
            "<C-_>",
            "hide",
            mode = "t",
            desc = "Hide Terminal",
          },
        },
      },
    },
    words = { enabled = true },
    styles = {
      notification = {
        -- wo = { wrap = true } -- Wrap notifications
      }
    },
  },
  keys = {
    -- Top Pickers & Explorer
    { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>n", function() Snacks.picker.notifications() end, desc = "Notifications" },
    { "<leader>fe", function() Snacks.explorer() end, desc = "File Explorer" },
    -- find
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>f.", function() Snacks.picker.files({ cwd = vim.fn.expand("%:p:h") }) end, desc = "Files Here" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
    -- Grep
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Lines" }, -- 在当前 buffer 中查询
    { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Buffers" }, -- 在所有打开的 buffer 中查询
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" }, -- 在所有文件中查询
    -- search
    { '<leader>s/', function() Snacks.picker.search_history() end, desc = "Search History" },
    { "<C-_>", function() Snacks.terminal.toggle() end, desc = "Toggle Terminal" },
  }
}
