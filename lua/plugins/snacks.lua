local utils = require("utils")

local function open_or_focus_explorer()
  local explorer = Snacks.picker.get({ source = "explorer" })[1]

  if explorer then
    explorer:focus()
    return
  end

  Snacks.explorer({ cwd = utils.tab_or_global_cwd() })
end

_G._terminal_names = _G._terminal_names or { [1] = "AI", [2] = "Shell" }

local function get_terminal_display_name(id)
  local name = _G._terminal_names[id]
  if name and name ~= "" then
    return name
  end
  if id == 1 then
    return "AI"
  elseif id == 2 then
    return "Shell"
  else
    return "Term " .. id
  end
end

_G.switch_terminal_by_id = function(target_id)
  vim.schedule(function()
    local target = Snacks.terminal.get(nil, { count = target_id })
    if not target then
      return
    end

    -- 1. 先展示并聚焦目标终端
    target:show():focus()
    vim.cmd("startinsert")

    -- 2. 同步关闭其他已打开的终端窗口（避免先关后开产生的空白闪烁）
    for _, t in ipairs(Snacks.terminal.list()) do
      if t ~= target and t:win_valid() then
        t:hide()
      end
    end
  end)
end

_G.create_new_terminal = function()
  vim.schedule(function()
    local active_ids = {}
    for _, t in ipairs(Snacks.terminal.list()) do
      if t.buf and vim.api.nvim_buf_is_valid(t.buf) then
        local info = vim.b[t.buf] and vim.b[t.buf].snacks_terminal
        if info and info.id then
          active_ids[info.id] = true
        end
      end
    end

    local next_id = 1
    while active_ids[next_id] do
      next_id = next_id + 1
    end

    _G.switch_terminal_by_id(next_id)
  end)
end

_G.hide_terminal_win = function()
  vim.schedule(function()
    for _, t in ipairs(Snacks.terminal.list()) do
      if t:win_valid() then
        t:hide()
      end
    end
  end)
end

_G.cycle_terminal = function(direction)
  vim.schedule(function()
    local cur_buf = vim.api.nvim_get_current_buf()
    local cur_term = vim.b[cur_buf] and vim.b[cur_buf].snacks_terminal
    local cur_id = cur_term and cur_term.id or 1

    local active_ids = {}
    for _, t in ipairs(Snacks.terminal.list()) do
      if t.buf and vim.api.nvim_buf_is_valid(t.buf) then
        local info = vim.b[t.buf] and vim.b[t.buf].snacks_terminal
        if info and info.id then
          table.insert(active_ids, info.id)
        end
      end
    end
    table.sort(active_ids)

    if #active_ids <= 1 then
      return
    end

    local cur_idx = 1
    for i, id in ipairs(active_ids) do
      if id == cur_id then
        cur_idx = i
        break
      end
    end

    local next_idx = cur_idx + direction
    if next_idx > #active_ids then
      next_idx = 1
    elseif next_idx < 1 then
      next_idx = #active_ids
    end

    _G.switch_terminal_by_id(active_ids[next_idx])
  end)
end

_G.rename_current_terminal = function(target_id)
  local id = target_id
  if not id then
    local cur_buf = vim.api.nvim_get_current_buf()
    local cur_term = vim.b[cur_buf] and vim.b[cur_buf].snacks_terminal
    id = cur_term and cur_term.id or 1
  end

  local cur_name = get_terminal_display_name(id)

  vim.schedule(function()
    vim.ui.input({
      prompt = "重命名终端 (" .. id .. "): ",
      default = cur_name,
    }, function(input)
      if input and vim.trim(input) ~= "" then
        _G._terminal_names[id] = vim.trim(input)
        vim.cmd("redrawtabline")
        vim.cmd("redrawstatus")
      end
      vim.schedule(function()
        local buf = vim.api.nvim_get_current_buf()
        if vim.bo[buf].buftype == "terminal" then
          vim.cmd("startinsert")
        end
      end)
    end)
  end)
end

_G.close_terminal_by_id = function(target_id)
  vim.schedule(function()
    local to_close = nil
    for _, t in ipairs(Snacks.terminal.list()) do
      if t.buf and vim.api.nvim_buf_is_valid(t.buf) then
        local info = vim.b[t.buf] and vim.b[t.buf].snacks_terminal
        if info and info.id == target_id then
          to_close = t
          break
        end
      end
    end

    if not to_close then
      return
    end

    local was_win = to_close:win_valid()
    local buf = to_close.buf

    -- 彻底删除 terminal buffer，终止底层进程并自动触发 BufWipeout 清理
    if buf and vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end

    -- 如果关闭的是当前可见的终端，自动切到剩余的终端
    if was_win then
      local remaining_ids = {}
      for _, t in ipairs(Snacks.terminal.list()) do
        if t.buf and vim.api.nvim_buf_is_valid(t.buf) then
          local info = vim.b[t.buf] and vim.b[t.buf].snacks_terminal
          if info and info.id and info.id ~= target_id then
            table.insert(remaining_ids, info.id)
          end
        end
      end
      table.sort(remaining_ids)
      if #remaining_ids > 0 then
        _G.switch_terminal_by_id(remaining_ids[1])
      end
    end
  end)
end

_G.on_terminal_tab_click = function(id, _, button)
  vim.schedule(function()
    if button == "r" then
      local utils = require("utils")
      local name = get_terminal_display_name(id)
      utils.open_in_place_menu("终端: " .. name, {
        {
          text = "切换到此终端",
          shortcut = "Enter",
          action = function()
            _G.switch_terminal_by_id(id)
          end,
        },
        {
          text = "重命名此终端",
          shortcut = "r",
          action = function()
            _G.rename_current_terminal(id)
          end,
        },
        {
          text = "关闭/终止此终端",
          shortcut = "x",
          action = function()
            _G.close_terminal_by_id(id)
          end,
        },
      })
    elseif button == "m" then
      _G.close_terminal_by_id(id)
    else
      _G.switch_terminal_by_id(id)
    end
  end)
end

_G.render_terminal_winbar = function()
  local cur_buf = vim.api.nvim_get_current_buf()
  local cur_term = vim.b[cur_buf] and vim.b[cur_buf].snacks_terminal
  local cur_id = cur_term and cur_term.id or 1

  local active_ids = {}
  local seen = {}
  for _, t in ipairs(Snacks.terminal.list()) do
    if t.buf and vim.api.nvim_buf_is_valid(t.buf) then
      local info = vim.b[t.buf] and vim.b[t.buf].snacks_terminal
      if info and info.id and not seen[info.id] then
        table.insert(active_ids, info.id)
        seen[info.id] = true
      end
    end
  end
  if not seen[cur_id] then
    table.insert(active_ids, cur_id)
  end
  table.sort(active_ids)

  local s = " "
  for _, id in ipairs(active_ids) do
    local is_sel = (id == cur_id)
    local name = get_terminal_display_name(id)
    local icon = (id == 1 or name:lower():find("ai")) and "󰚩 " or " "

    local hl = is_sel and "%#TabLineSel#" or "%#TabLine#"
    s = s .. hl
    s = s .. "%" .. id .. "@v:lua.on_terminal_tab_click@"
    s = s .. " " .. icon .. id .. ": " .. name .. " "
    s = s .. "%T"
    s = s .. "%#Normal# "
  end

  -- 新建终端加号按钮 (+)
  s = s .. "%@v:lua.create_new_terminal@%#TabLineNew#  + %T%#Normal#"

  -- 靠右对齐部分
  s = s .. "%="

  -- 模式提示
  local mode_text = (vim.fn.mode(1) == "t") and "INPUT" or "NORMAL"
  s = s .. "%#Comment#[" .. mode_text .. "] "

  -- 收起/隐藏按钮 ()
  s = s .. "%@v:lua.hide_terminal_win@%#TabLineCloseSel#  收起 %T "

  return s
end

local function terminal_keys()
  local keys = {
    term_hide = {
      "<C-\\>",
      "hide",
      mode = "t",
      desc = "Hide Terminal",
    },
    term_new = {
      "<A-c>",
      function()
        _G.create_new_terminal()
      end,
      mode = { "t", "n" },
      desc = "New Terminal Tab",
    },
    term_rename = {
      "<A-r>",
      function()
        _G.rename_current_terminal()
      end,
      mode = { "t", "n" },
      desc = "Rename Terminal",
    },
    term_next = {
      "<A-n>",
      function()
        _G.cycle_terminal(1)
      end,
      mode = { "t", "n" },
      desc = "Next Terminal Tab",
    },
    term_prev = {
      "<A-p>",
      function()
        _G.cycle_terminal(-1)
      end,
      mode = { "t", "n" },
      desc = "Prev Terminal Tab",
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
    -- 在终端模式下直接 Alt + 数字秒切，无需退出输入模式！
    keys["terminal_alt_" .. count] = {
      "<A-" .. count .. ">",
      function()
        _G.switch_terminal_by_id(count)
      end,
      mode = { "t", "n" },
      desc = "Switch to Terminal " .. count,
    }
    -- 在 Normal 模式下直接按单个数字 1~9 秒切
    keys["terminal_num_" .. count] = {
      tostring(count),
      function()
        _G.switch_terminal_by_id(count)
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
        width = 0.8,
        height = 0.8,
        backdrop = false,
        wo = {
          winblend = 15,
          winbar = "%!v:lua.render_terminal_winbar()",
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
