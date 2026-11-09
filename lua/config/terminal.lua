local M = {}
local links = require("config.terminal_links")
local menu = require("config.context_menu")
local terminals = {}
local pending = {}
local names = {}
local last_id = 1

-- 编号在整个 Neovim 会话中唯一；创建时固定 cwd，之后按对象切换。
function M.list()
  local ids = {}
  for id, terminal in pairs(terminals) do
    if terminal:buf_valid() then
      ids[#ids + 1] = id
    else
      terminals[id] = nil
    end
  end
  table.sort(ids)
  return ids
end

function M.display_name(id)
  return names[id] or ({ "AI", "Shell" })[id] or ("Term " .. id)
end

function M.switch(id)
  vim.schedule(function()
    pending[id] = nil
    local target = terminals[id]
    if not (target and target:buf_valid()) then
      target = Snacks.terminal.open(nil, { count = id, cwd = require("utils").tab_or_global_cwd() })
      terminals[id] = target
      target:on("BufWipeout", function()
        if terminals[id] == target then
          terminals[id] = nil
          names[id] = nil
        end
      end, { buf = true })
    end
    last_id = id
    if target:win_valid() and vim.api.nvim_win_get_tabpage(target.win) ~= vim.api.nvim_get_current_tabpage() then
      target:hide()
    end
    target:show():focus()
    vim.cmd.startinsert()
    for _, other in pairs(terminals) do
      if other ~= target and other:win_valid() then
        other:hide()
      end
    end
  end)
end

function M.toggle()
  local ids = M.list()
  if not terminals[last_id] then
    last_id = ids[1] or 1
  end
  local target = terminals[last_id]
  if
    target
    and target:win_valid()
    and vim.api.nvim_win_get_tabpage(target.win) == vim.api.nvim_get_current_tabpage()
  then
    target:hide()
  else
    M.switch(last_id)
  end
end

function M.create()
  M.list()
  local id = 1
  while terminals[id] or pending[id] do
    id = id + 1
  end
  pending[id] = true
  M.switch(id)
end

function M.hide()
  for id, terminal in pairs(terminals) do
    if terminal:win_valid() then
      last_id = id
      terminal:hide()
    end
  end
end

function M.cycle(direction)
  local ids = M.list()
  if #ids < 2 then
    return
  end
  local info = vim.b.snacks_terminal
  local current = info and info.id or last_id
  local index = 1
  for i, id in ipairs(ids) do
    if id == current then
      index = i
      break
    end
  end
  M.switch(ids[(index - 1 + direction) % #ids + 1])
end

function M.rename(id)
  local info = vim.b.snacks_terminal
  id = id or (info and info.id) or last_id
  vim.ui.input({ prompt = "重命名终端 (" .. id .. "): ", default = M.display_name(id) }, function(input)
    if terminals[id] and terminals[id]:buf_valid() and input and vim.trim(input) ~= "" then
      names[id] = vim.trim(input)
      vim.cmd.redrawstatus()
    end
  end)
end

function M.close(id)
  vim.schedule(function()
    local target = terminals[id]
    if not target then
      return
    end
    local was_visible = target:win_valid()
    if target:buf_valid() then
      vim.api.nvim_buf_delete(target.buf, { force = true })
    end
    terminals[id], names[id] = nil, nil
    local ids = M.list()
    if last_id == id then
      last_id = ids[1] or 1
    end
    if was_visible and #ids > 0 then
      M.switch(last_id)
    end
  end)
end

function M.on_tab_click(id, _, button)
  vim.schedule(function()
    if button == "r" then
      menu.open_in_place_menu("终端: " .. M.display_name(id), {
        {
          text = "切换到此终端",
          shortcut = "Enter",
          action = function()
            M.switch(id)
          end,
        },
        {
          text = "重命名此终端",
          shortcut = "r",
          action = function()
            M.rename(id)
          end,
        },
        {
          text = "关闭/终止此终端",
          shortcut = "x",
          action = function()
            M.close(id)
          end,
        },
      })
    elseif button == "m" then
      M.close(id)
    elseif button == "l" then
      M.switch(id)
    end
  end)
end

function M.render()
  local info = vim.b.snacks_terminal
  local current = info and info.id or last_id
  local parts = { " " }
  for _, id in ipairs(M.list()) do
    local name = M.display_name(id)
    local icon = (id == 1 or name:lower():find("ai", 1, true)) and "󰚩 " or " "
    parts[#parts + 1] = (id == current and "%#TabLineSel#" or "%#TabLine#")
      .. "%"
      .. id
      .. "@v:lua.require'config.terminal'.on_tab_click@ "
      .. icon
      .. id
      .. ": "
      .. name:gsub("%%", "%%%%")
      .. " %T%#Normal# "
  end
  parts[#parts + 1] = "%@v:lua.require'config.terminal'.create@%#TabLineNew#  + %T%#Normal#%="
  parts[#parts + 1] = "%#Comment#[" .. (vim.fn.mode(1) == "t" and "INPUT" or "NORMAL") .. "] "
  parts[#parts + 1] = "%@v:lua.require'config.terminal'.hide@%#TabLineCloseSel#  收起 %T "
  return table.concat(parts)
end

function M.keys()
  local keys = {
    term_jump_ctrl_click = {
      "<C-LeftMouse>",
      function(self)
        links.try_jump_from_mouse(self)
      end,
      mode = { "t", "n" },
      desc = "Ctrl+Click on file path to jump",
    },
    term_jump_double_click = {
      "<2-LeftMouse>",
      function(self)
        links.try_jump_from_mouse(self)
      end,
      mode = { "t", "n" },
      desc = "Double click file path to jump",
    },
    term_jump_cr = {
      "<CR>",
      function(self)
        if not links.try_jump_from_cursor(self) then
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "n", false)
        end
      end,
      mode = "n",
      desc = "Press Enter on file path in normal mode to jump",
    },
    term_hide = {
      "<C-\\>",
      function(self)
        if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
          local info = vim.b[self.buf] and vim.b[self.buf].snacks_terminal
          if info and info.id then
            last_id = info.id
          end
        end
        self:hide()
      end,
      mode = "t",
      desc = "Hide Terminal",
    },
    term_new = {
      "<A-c>",
      function()
        M.create()
      end,
      mode = { "t", "n" },
      desc = "New Terminal Tab",
    },
    term_rename = {
      "<A-r>",
      function()
        M.rename()
      end,
      mode = { "t", "n" },
      desc = "Rename Terminal",
    },
    term_next = {
      "<A-n>",
      function()
        M.cycle(1)
      end,
      mode = { "t", "n" },
      desc = "Next Terminal Tab",
    },
    term_prev = {
      "<A-p>",
      function()
        M.cycle(-1)
      end,
      mode = { "t", "n" },
      desc = "Prev Terminal Tab",
    },
    term_normal = {
      "<Esc>",
      function(self)
        local now = vim.uv.hrtime()
        if self.last_escape and now - self.last_escape < 500000000 then
          self.last_escape = nil
          vim.schedule(function()
            vim.cmd.stopinsert()
          end)
          return ""
        end
        self.last_escape = now
        return "<Esc>"
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
        M.switch(count)
      end,
      mode = { "t", "n" },
      desc = "Switch to Terminal " .. count,
    }
    -- 在 Normal 模式下直接按单个数字 1~9 秒切
    keys["terminal_num_" .. count] = {
      tostring(count),
      function()
        M.switch(count)
      end,
      mode = "n",
      desc = "Switch to Terminal " .. count,
    }
  end

  return keys
end

return M
