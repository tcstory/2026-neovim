local utils = require("utils")

local function is_normal_file_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
end

local function file_history_action()
  return function()
    local file = vim.api.nvim_buf_get_name(0)
    if file == "" or vim.bo.buftype ~= "" then
      vim.notify("File History 仅支持普通文件缓冲区", vim.log.levels.WARN)
      return
    end

    require("lazy").load({ plugins = { "diffview-plus.nvim" } })
    vim.cmd("DiffviewFileHistory %")
  end
end

local function is_click_in_statuscolumn(winid, wincol)
  local wininfo = vim.fn.getwininfo(winid)
  if wininfo and #wininfo > 0 then
    local textoff = wininfo[1].textoff or 0
    return textoff > 0 and wincol <= textoff
  end
  return false
end

local function find_blame_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) then
      local b = vim.api.nvim_win_get_buf(win)
      if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "gitsigns-blame" then
        return win
      end
    end
  end
  return nil
end

local function get_statuscolumn_menu_items()
  local blame_win = find_blame_win()
  if blame_win then
    return {
      {
        text = "关闭 Git Blame",
        action = function()
          if vim.api.nvim_win_is_valid(blame_win) then
            vim.api.nvim_win_close(blame_win, true)
          end
        end,
        shortcut = "q",
      },
    }
  end

  return {
    { text = "Git Blame", action = function() vim.cmd("Gitsigns blame") end, shortcut = "git" },
  }
end

local function get_editor_menu_items()
  return {
    { text = "复制当前文件地址", action = utils.copy_current_file_path_from_tcd, shortcut = "yf" },
    { text = "复制当前文件所在目录", action = utils.copy_current_file_dir_from_tcd, shortcut = "yd" },
    { text = "Diff This", action = utils.diff_current_file, shortcut = "HEAD" },
    { text = "File History", action = file_history_action(), shortcut = "Hist" },
  }
end

local function setup_file_menu()
  vim.keymap.set({ "n", "v" }, "<RightMouse>", function()
    vim.cmd.exec('"normal! \\<RightMouse>"')

    local mouse = vim.fn.getmousepos()

    -- 检查 Tabline 是否可见（showtabline=2 或 showtabline=1且多于1个tabpage）
    local tabline_visible = (vim.o.showtabline == 2)
      or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)

    -- 如果 Tabline 可见且点击在第 1 行（Tabline 所在行），不弹出编辑器菜单
    if tabline_visible and mouse.screenrow == 1 then
      return
    end

    local winid = (mouse.winid ~= 0 and vim.api.nvim_win_is_valid(mouse.winid)) and mouse.winid
      or vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(winid)

    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "gitsigns-blame" then
      if vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_set_current_win(winid)
        if mouse.line > 0 then
          pcall(vim.api.nvim_win_set_cursor, winid, { mouse.line, 0 })
        end
      end

      local lnum = mouse.line > 0 and mouse.line or vim.api.nvim_win_get_cursor(winid)[1]
      local info = utils.get_blame_commit_at_line(winid, lnum)

      local menu_title = "Git Blame"
      local menu_items = {}

      if info and info.sha and not info.is_uncommitted then
        local summary_preview = info.summary ~= "" and (": " .. info.summary) or ""
        if vim.fn.strdisplaywidth(summary_preview) > 28 then
          summary_preview = summary_preview:sub(1, 25) .. "..."
        end
        menu_title = info.abbrev_sha .. summary_preview

        table.insert(menu_items, {
          text = "在 Git 图谱中定位此提交",
          action = function()
            utils.show_commit_in_graph(info.sha)
          end,
          shortcut = "Enter",
        })
        table.insert(menu_items, {
          text = "查看此提交完整改动 (Diff)",
          action = function()
            utils.show_commit_diff(info.sha)
          end,
          shortcut = "d",
        })
        table.insert(menu_items, {
          text = "复制 Commit Hash",
          action = function()
            vim.fn.setreg("+", info.sha)
            vim.notify("已复制 Commit Hash: " .. info.sha)
          end,
          shortcut = "y",
        })
      else
        menu_title = "Git Blame (未提交改动)"
        table.insert(menu_items, {
          text = "查看本地改动 (Diff This)",
          action = utils.diff_current_file,
          shortcut = "d",
        })
      end

      table.insert(menu_items, {
        text = "关闭 Git Blame",
        action = function()
          if vim.api.nvim_win_is_valid(winid) then
            vim.api.nvim_win_close(winid, true)
          end
        end,
        shortcut = "q",
      })

      utils.open_in_place_menu(menu_title, menu_items)
      return
    end

    if not is_normal_file_buffer(buf) then
      return
    end

    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_set_current_win(winid)
      if mouse.line > 0 then
        pcall(vim.api.nvim_win_set_cursor, winid, { mouse.line, 0 })
      end
    end

    local filename = vim.fs.basename(vim.api.nvim_buf_get_name(buf))
    if is_click_in_statuscolumn(winid, mouse.wincol) then
      utils.open_in_place_menu(filename, get_statuscolumn_menu_items())
    else
      utils.open_in_place_menu(filename, get_editor_menu_items())
    end
  end, { desc = "Open context menu" })
end

return {
  {
    name = "native-context-menu",
    dir = vim.fn.stdpath("config"),
    lazy = false,
    config = setup_file_menu,
  },
}
