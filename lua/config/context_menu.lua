local M = {}

local active_menu_close = nil

function M.cancel_active_inputs()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "snacks_input" then
        vim.api.nvim_win_call(win, function()
          vim.cmd("stopinsert")
          vim.cmd("normal q")
        end)
      end
    end
  end
end

function M.open_in_place_menu(title, items)
  if active_menu_close then
    pcall(active_menu_close)
    active_menu_close = nil
  end

  M.cancel_active_inputs()

  local mouse = vim.fn.getmousepos()
  local lines = {}
  local shortcuts = {}
  local has_any_shortcut = false

  for _, item in ipairs(items) do
    local sc = item.shortcut or item.rtxt
    if sc and sc ~= "" then
      has_any_shortcut = true
      break
    end
  end

  local max_left = 0
  if has_any_shortcut then
    for _, item in ipairs(items) do
      local label = item.text or item.name or ""
      max_left = math.max(max_left, vim.fn.strdisplaywidth(label))
    end
  end

  local max_width = (title and title ~= "") and (vim.fn.strdisplaywidth(title) + 4) or 10

  for _, item in ipairs(items) do
    local label = item.text or item.name or ""
    local text
    local sc_info = nil
    if has_any_shortcut then
      local sc = item.shortcut or item.rtxt or ""
      local spaces = string.rep(" ", max_left - vim.fn.strdisplaywidth(label) + 3)
      local prefix = "  " .. label .. spaces
      text = prefix .. sc .. "  "
      if sc ~= "" then
        sc_info = { start_col = #prefix, end_col = #prefix + #sc }
      end
    else
      text = "  " .. label .. "  "
    end
    table.insert(lines, text)
    table.insert(shortcuts, sc_info or false)
    max_width = math.max(max_width, vim.fn.strdisplaywidth(text))
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].filetype = "native_context_menu"

  local ns_id = vim.api.nvim_create_namespace("native_context_menu")
  for idx, sc_info in ipairs(shortcuts) do
    if sc_info then
      pcall(vim.api.nvim_buf_set_extmark, buf, ns_id, idx - 1, sc_info.start_col, {
        end_col = sc_info.end_col,
        hl_group = "Comment",
      })
    end
  end

  local height = #lines
  local width = max_width
  local row = 0
  local col = 1
  local relative = "mouse"

  if not mouse.screenrow or mouse.screenrow == 0 then
    relative = "cursor"
    row = 1
    col = 0
  else
    if mouse.screenrow + height + 2 > vim.o.lines then
      row = -height - 1
    end
    if mouse.screencol and mouse.screencol + width + 2 > vim.o.columns then
      col = -width
    end
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = relative,
    row = row,
    col = col,
    width = width,
    height = height,
    style = "minimal",
    -- Keep the menu above its source window, including floating explorers.
    zindex = math.max(50, (vim.api.nvim_win_get_config(0).zindex or 0) + 1),
    border = "rounded",
    title = (title and title ~= "") and (" " .. title .. " ") or nil,
    title_pos = "center",
  })

  vim.wo[win].cursorline = true
  vim.wo[win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:Visual"

  local closed = false
  local function close_menu()
    if closed then
      return
    end
    closed = true
    if active_menu_close == close_menu then
      active_menu_close = nil
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  active_menu_close = close_menu

  local function select_index(idx)
    if idx >= 1 and idx <= #items then
      local choice = items[idx]
      close_menu()
      local act = choice.action or choice.cmd
      if act then
        if type(act) == "function" then
          vim.schedule(act)
        elseif type(act) == "string" then
          vim.schedule(function()
            vim.cmd(act)
          end)
        end
      end
    end
  end

  vim.keymap.set("n", "<CR>", function()
    local cursor = vim.api.nvim_win_get_cursor(win)
    select_index(cursor[1])
  end, { buffer = buf, silent = true, nowait = true })

  vim.keymap.set("n", "<LeftMouse>", function()
    local m = vim.fn.getmousepos()
    if m.winid == win then
      select_index(m.line)
    else
      close_menu()
    end
  end, { buffer = buf, silent = true, nowait = true })

  vim.keymap.set("n", "<RightMouse>", close_menu, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "<Esc>", close_menu, { buffer = buf, silent = true, nowait = true })
  vim.keymap.set("n", "q", close_menu, { buffer = buf, silent = true, nowait = true })

  for index, item in ipairs(items) do
    local shortcut = item.shortcut or item.rtxt
    if shortcut and shortcut ~= "" and shortcut ~= "Enter" and shortcut ~= "<CR>" then
      vim.keymap.set("n", shortcut, function()
        select_index(index)
      end, {
        buffer = buf,
        silent = true,
        desc = item.text or item.name,
      })
    end
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = close_menu,
  })

  return close_menu
end

return M
