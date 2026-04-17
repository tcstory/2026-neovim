return {
  "nvzone/menu",
  dependencies = {
    "nvzone/volt",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    local utils = require("utils")

    local function is_normal_file_buffer(buf)
      return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
    end

    local function get_explorer_picker(winid)
      for _, picker in ipairs(Snacks.picker.get({ source = "explorer", tab = false })) do
        local list_win = picker.layout
          and picker.layout.wins
          and picker.layout.wins.list
          and picker.layout.wins.list.win

        if list_win == winid then
          return picker
        end
      end
    end

    local file_menu_items = {
      { name = "复制当前文件地址", cmd = utils.copy_current_file_path_from_tcd, rtxt = "yf" },
      { name = "复制当前文件所在目录", cmd = utils.copy_current_file_dir_from_tcd, rtxt = "yd" },
      { name = "Diff This", cmd = utils.diff_current_file, rtxt = "HEAD" },
      { name = "Diff File Last Change", cmd = utils.diff_current_file_last_change, rtxt = "Last" },
    }

    vim.keymap.set({ "n", "v" }, "<RightMouse>", function()
      require("menu.utils").delete_old_menus()

      vim.cmd.exec('"normal! \\<RightMouse>"')

      local mouse = vim.fn.getmousepos()
      local buf = mouse.winid ~= 0 and vim.api.nvim_win_get_buf(mouse.winid) or vim.api.nvim_get_current_buf()
      local winid = mouse.winid ~= 0 and mouse.winid or vim.api.nvim_get_current_win()
      local explorer = get_explorer_picker(winid)

      if vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_set_current_win(winid)
      end

      if explorer then
        local target_dir = explorer:dir()
        local explorer_menu_items = {
          {
            name = "搜索此目录中的文件内容",
            cmd = function()
              Snacks.picker.grep({ cwd = target_dir })
            end,
            rtxt = "grep",
          },
          {
            name = "搜索此目录中的文件名",
            cmd = function()
              Snacks.picker.files({ cwd = target_dir })
            end,
            rtxt = "files",
          },
        }

        require("menu").open(explorer_menu_items, { mouse = true })
        return
      end

      if not is_normal_file_buffer(buf) then
        return
      end

      require("menu").open(file_menu_items, { mouse = true })
    end, { desc = "Open context menu" })
  end,
}
