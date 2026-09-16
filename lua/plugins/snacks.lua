local utils = require("utils")

local function open_or_focus_explorer()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]

  if explorer then
    explorer:focus()
    return
  end

  Snacks.explorer({ cwd = utils.tab_or_global_cwd() })
end

local function switch_terminal(self, count)
  local terminal = vim.b[self.buf].snacks_terminal

  if terminal and terminal.id == count then
    return
  end

  self:hide()
  vim.schedule(function()
    local target = Snacks.terminal.focus(nil, { count = count })

    vim.schedule(function()
      if target and vim.api.nvim_get_current_buf() == target.buf then
        vim.cmd("stopinsert")
      end
    end)
  end)
end

local function terminal_keys()
  local keys = {
    term_hide = {
      "<C-\\>",
      "hide",
      mode = "t",
      desc = "Hide Terminal",
    },
    term_normal = {
      "<Esc>",
      function(self)
        self.esc_timer = self.esc_timer or (vim.uv or vim.loop).new_timer()

        if self.esc_timer:is_active() then
          self.esc_timer:stop()
          vim.cmd("stopinsert")
        else
          self.esc_timer:start(500, 0, function() end)
          return "<Esc>"
        end
      end,
      mode = "t",
      expr = true,
      desc = "Double escape to normal mode",
    },
  }

  for count = 1, 9 do
    keys["terminal_" .. count] = {
      tostring(count),
      function(self)
        switch_terminal(self, count)
      end,
      mode = "n",
      desc = "Switch to Terminal " .. count,
    }
  end

  return keys
end

return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "snacks_input",
      group = vim.api.nvim_create_augroup("tcstory_snacks_input_autoclose", { clear = true }),
      callback = function(ev)
        vim.api.nvim_create_autocmd("BufLeave", {
          buffer = ev.buf,
          once = true,
          callback = function()
            vim.schedule(function()
              if vim.api.nvim_buf_is_valid(ev.buf) then
                for _, win in ipairs(vim.api.nvim_list_wins()) do
                  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == ev.buf then
                    vim.api.nvim_win_call(win, function()
                      vim.cmd("stopinsert")
                      vim.cmd("normal q")
                    end)
                    break
                  end
                end
              end
            end)
          end,
        })
      end,
    })
  end,
  config = function(_, opts)
    require("snacks").setup(opts)

    -- 点击行号/状态列时仅定位光标，不触发代码折叠 (去除默认的 za 行为)
    require("snacks.statuscolumn").click_fold = function()
      local pos = vim.fn.getmousepos()
      if pos.winid > 0 and vim.api.nvim_win_is_valid(pos.winid) and pos.line > 0 then
        vim.api.nvim_set_current_win(pos.winid)
        pcall(vim.api.nvim_win_set_cursor, pos.winid, { pos.line, 0 })
      end
    end
  end,
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
      actions = {
        explorer_context_menu = function(picker)
          utils.cancel_active_inputs()
          local mouse = vim.fn.getmousepos()
          if mouse.winid == picker.list.win.win then
            picker.list.win:focus()
            local idx = picker.list:row2idx(mouse.line)
            if idx >= 1 and idx <= picker.list:count() then
              picker.list:_move(idx, true, true)
            end
          end

          local item = picker:current()
          if not item then
            return
          end

          local target_dir = picker:dir()
          local target_path = item.file
          local name = item.file and vim.fs.basename(item.file) or target_dir

          local menu_items = {
            {
              text = "搜索此目录内容 (Grep)",
              action = function()
                Snacks.picker.grep({ cwd = target_dir })
              end,
            },
            {
              text = "在此目录查找文件 (Files)",
              action = function()
                Snacks.picker.files({ cwd = target_dir })
              end,
            },
            {
              text = "复制相对路径",
              action = function()
                utils.copy_path_from_tcd(target_path)
              end,
            },
            {
              text = "复制目录相对路径",
              action = function()
                utils.copy_dir_from_tcd(target_dir)
              end,
            },
            {
              text = "新建文件 / 目录 (Add)",
              action = function()
                picker:action("explorer_add")
              end,
            },
            {
              text = "重命名 (Rename)",
              action = function()
                picker:action("explorer_rename")
              end,
            },
            {
              text = "删除 / 移到回收站 (Delete)",
              action = function()
                picker:action("explorer_del")
              end,
            },
            {
              text = "复制 (Copy)",
              action = function()
                picker:action("explorer_copy")
              end,
            },
            {
              text = "剪切 / 移动 (Move)",
              action = function()
                picker:action("explorer_move")
              end,
            },
            {
              text = "粘贴到此目录 (Paste)",
              action = function()
                picker:action("explorer_paste")
              end,
            },
          }

          utils.open_in_place_menu(name, menu_items)
        end,
      },
      sources = {
        explorer = {
          hidden = true,
          ignored = true,
          win = {
            list = {
              keys = {
                ["<RightMouse>"] = "explorer_context_menu",
              },
            },
            input = {
              keys = {
                ["<RightMouse>"] = "explorer_context_menu",
              },
            },
          },
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
        wo = {
          winbar = "%=%{printf('Terminal %d · %d active · %s', exists('b:snacks_terminal') ? b:snacks_terminal.id : 1, luaeval('#Snacks.terminal.list()'), mode(1) ==# 't' ? 'INPUT' : 'NORMAL')}%=",
        },
        keys = terminal_keys(),
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
