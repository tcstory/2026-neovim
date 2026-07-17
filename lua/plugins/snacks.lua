local utils = require("utils")

local function open_or_focus_explorer()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]

  if explorer then
    explorer:focus()
    return
  end

  Snacks.explorer({ cwd = utils.tab_or_global_cwd() })
end

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    bigfile = { enabled = true },
    dashboard = {
      enabled = true,
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        {
          section = "projects",
          title = "Projects",
          icon = " ",
          padding = 1,
          limit = 5,
          action = function(dir)
            vim.cmd.tcd(dir)
            Snacks.dashboard.pick("files")
          end,
        },
        { section = "startup" },
      },
    },
    explorer = { enabled = true },
    indent = { enabled = true },
    input = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    picker = {
      enabled = true,
      sources = {
        explorer = {
          hidden = true,
        },
      },
    },
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
            "<C-\\>",
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
    -- { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
    { "<leader>n", function() Snacks.picker.notifications() end, desc = "Notifications" },
    { "<leader>fe", function() Snacks.explorer({ cwd = utils.tab_or_global_cwd() }) end, desc = "File Explorer" },
    { "<leader>1", open_or_focus_explorer, desc = "Open or Focus Explorer" },
    -- find
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>f.", function() Snacks.picker.files({ cwd = vim.fn.expand("%:p:h") }) end, desc = "Files Here" },
    -- { "<leader>ff", function() Snacks.picker.files({ cwd = utils.tab_or_global_cwd() }) end, desc = "Find Files" },
    { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },
    -- { "<leader>fy", utils.copy_current_file_path_from_tcd, desc = "Yank File Path From tcd" },
    -- {
    --   "<leader>fc",
    --   function()
    --     local cwd
    --
    --     if vim.fn.haslocaldir() == 1 then
    --       cwd = vim.fn.getcwd(0)
    --     elseif vim.fn.getcwd(-1, 0) ~= vim.fn.getcwd(-1, -1) then
    --       cwd = vim.fn.getcwd(-1, 0)
    --     else
    --       cwd = vim.fn.getcwd(-1, -1)
    --     end
    --     Snacks.picker.files({ cwd = cwd })
    --   end,
    --   desc = "Files Current",
    -- },
    -- Grep
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Lines" }, -- 在当前 buffer 中查询
    { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep Buffers" }, -- 在所有打开的 buffer 中查询
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep" }, -- 在所有文件中查询
    -- search
    -- { '<leader>s/', function() Snacks.picker.search_history() end, desc = "Search History" },
    { "<C-\\>", function() Snacks.terminal.toggle() end, desc = "Toggle Terminal" },
  }
}
