local M = {}

local devicons_ok, devicons = pcall(require, "nvim-web-devicons")

local function get_tab_title(tabpage)
  local win = vim.api.nvim_tabpage_get_win(tabpage)
  if not vim.api.nvim_win_is_valid(win) then
    return "[Tab]"
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) then
    return "[Tab]"
  end

  local buftype = vim.bo[buf].buftype
  local bufname = vim.api.nvim_buf_get_name(buf)

  if buftype == "terminal" then
    return "[Terminal]"
  elseif buftype == "quickfix" then
    return "[Quickfix]"
  elseif buftype == "help" then
    return "[Help]"
  elseif bufname == "" then
    return "[No Name]"
  else
    local name = vim.fs.basename(bufname)
    return name ~= "" and name or "[No Name]"
  end
end

local function get_tab_icon(tabpage)
  if not devicons_ok then
    return ""
  end
  local win = vim.api.nvim_tabpage_get_win(tabpage)
  if not vim.api.nvim_win_is_valid(win) then
    return ""
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.api.nvim_buf_is_valid(buf) then
    return ""
  end

  local bufname = vim.api.nvim_buf_get_name(buf)
  local ext = vim.fn.fnamemodify(bufname, ":e")
  local icon = devicons.get_icon(bufname, ext, { default = true })
  return icon and (icon .. " ") or ""
end

local function is_tab_modified(tabpage)
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
        return true
      end
    end
  end
  return false
end

local function get_tab_window_count(tabpage)
  local count = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if vim.api.nvim_win_is_valid(win) then
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg.relative == "" then
        count = count + 1
      end
    end
  end
  return count
end

function M.on_tab_click(tab_nr, _, button)
  local tabpages = vim.api.nvim_list_tabpages()
  local tabpage = tabpages[tab_nr]
  if not tabpage or not vim.api.nvim_tabpage_is_valid(tabpage) then
    return
  end

  if button == "l" then
    vim.api.nvim_set_current_tabpage(tabpage)
  elseif button == "m" then
    vim.cmd(tab_nr .. "tabclose")
  elseif button == "r" then
    local utils = require("utils")
    local title = get_tab_title(tabpage)
    local tab_cwd = vim.fn.getcwd(-1, tab_nr)

    utils.open_in_place_menu("工作区: " .. title, {
      {
        text = "切换到此工作区",
        shortcut = "Enter",
        action = function()
          if vim.api.nvim_tabpage_is_valid(tabpage) then
            vim.api.nvim_set_current_tabpage(tabpage)
          end
        end,
      },
      {
        text = "关闭此工作区",
        shortcut = "x",
        action = function()
          vim.cmd(tab_nr .. "tabclose")
        end,
      },
      {
        text = "关闭其他工作区",
        shortcut = "o",
        action = function()
          if vim.api.nvim_tabpage_is_valid(tabpage) then
            vim.api.nvim_set_current_tabpage(tabpage)
          end
          vim.cmd("tabonly")
        end,
      },
      {
        text = "在此工作区新建分屏",
        shortcut = "s",
        action = function()
          if vim.api.nvim_tabpage_is_valid(tabpage) then
            vim.api.nvim_set_current_tabpage(tabpage)
            vim.cmd("vsplit")
          end
        end,
      },
      {
        text = "复制工作区路径 (tcd)",
        shortcut = "yd",
        action = function()
          vim.fn.setreg("+", tab_cwd)
          vim.notify("已复制工作区路径: " .. tab_cwd)
        end,
      },
    })
  end
end

function M.on_close_click(tab_nr, _, button)
  if button and button ~= "l" and button ~= "" then
    return
  end
  local tabpages = vim.api.nvim_list_tabpages()
  local tabpage = tabpages[tab_nr]
  if tabpage and vim.api.nvim_tabpage_is_valid(tabpage) then
    vim.cmd(tab_nr .. "tabclose")
  end
end

function M.on_new_tab_click(_, _, button)
  if button and button ~= "l" and button ~= "" then
    return
  end
  vim.cmd("tabnew")
end

function M.render()
  local tabpages = vim.api.nvim_list_tabpages()
  local cur_tab = vim.api.nvim_get_current_tabpage()
  local s = ""

  for i, tabpage in ipairs(tabpages) do
    local is_selected = (tabpage == cur_tab)
    local title = get_tab_title(tabpage)
    local icon = get_tab_icon(tabpage)
    local modified = is_tab_modified(tabpage)
    local win_count = get_tab_window_count(tabpage)

    if is_selected then
      s = s .. "%#TabLineSel#"
    else
      s = s .. "%#TabLine#"
    end

    -- Tab 主体点击响应区域 (左键切换，右键菜单，中键关闭)
    s = s .. "%" .. i .. "@v:lua.require'tabline'.on_tab_click@"

    s = s .. " " .. icon .. i .. " " .. title

    if win_count > 1 then
      s = s .. " [" .. win_count .. "]"
    end

    if modified then
      s = s .. " %#TabLineMod#●" .. (is_selected and "%#TabLineSel#" or "%#TabLine#")
    end

    -- 结束 Tab 主体响应区域
    s = s .. "%T"

    -- 独立的关闭按钮点击热区 (同时支持原生 %X 与 Lua 回调，宽度扩大为 '  ')
    local close_hl = is_selected and "%#TabLineCloseSel#" or "%#TabLineClose#"
    s = s .. "%" .. i .. "X%" .. i .. "@v:lua.require'tabline'.on_close_click@" .. close_hl .. "  %T%X" .. (is_selected and "%#TabLineSel#" or "%#TabLine#")
  end

  -- 填充剩余顶栏背景
  s = s .. "%#TabLineFill#%="

  -- 最右侧的加号新建工作区按钮
  s = s .. "%@v:lua.require'tabline'.on_new_tab_click@%#TabLineNew#  %*%T "

  return s
end

local function setup_highlights()
  local ok, c = pcall(function()
    return require("tokyonight.colors").setup()
  end)

  if ok and c then
    vim.api.nvim_set_hl(0, "TabLineSel", {
      bg = c.bg_visual or "#2e3c64",
      fg = "#ffffff",
      bold = true,
    })
    vim.api.nvim_set_hl(0, "TabLine", {
      bg = c.bg_dark or "#1f2335",
      fg = c.fg_dark or "#7982a9",
    })
    vim.api.nvim_set_hl(0, "TabLineFill", {
      bg = c.bg_dark1 or "#1b1e2d",
    })
    vim.api.nvim_set_hl(0, "TabLineMod", {
      fg = c.warning or "#e0af68",
      bold = true,
    })
    vim.api.nvim_set_hl(0, "TabLineClose", {
      bg = c.bg_dark or "#1f2335",
      fg = c.red or "#f7768e",
    })
    vim.api.nvim_set_hl(0, "TabLineCloseSel", {
      bg = c.bg_visual or "#2e3c64",
      fg = c.red or "#f7768e",
    })
    vim.api.nvim_set_hl(0, "TabLineNew", {
      fg = c.blue or "#7aa2f7",
      bold = true,
    })
  end
end

function M.setup(opts)
  opts = opts or {}

  setup_highlights()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("tcstory_tabline_colors", { clear = true }),
    callback = setup_highlights,
  })

  -- 只有多于 1 个工作区时自动显示头部标签栏
  vim.o.showtabline = opts.showtabline or 1
  vim.o.tabline = "%!v:lua.require'tabline'.render()"
end

return M
