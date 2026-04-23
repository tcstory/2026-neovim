return {
  "nvzone/menu",
  dependencies = {
    "nvzone/volt",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    local utils = require("utils")
    local menu_utils = require("menu.utils")

    local function is_normal_file_buffer(buf)
      return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
    end

    local function menu_action(cmd)
      return function()
        menu_utils.delete_old_menus()
        vim.schedule(function()
          if type(cmd) == "string" then
            vim.cmd(cmd)
          else
            cmd()
          end
        end)
      end
    end

    local function picker_menu_action(source, open)
      return menu_action(function()
        open()
        vim.schedule(function()
          local pickers = Snacks.picker.get({ source = source })
          local picker = pickers[#pickers]

          if not picker or picker.closed then
            return
          end

          picker:focus("input", { show = true })
          vim.schedule(function()
            if picker.input
              and picker.input.win
              and picker.input.win.win
              and vim.api.nvim_win_is_valid(picker.input.win.win) then
              vim.api.nvim_set_current_win(picker.input.win.win)
              vim.cmd("startinsert!")
            end
          end)
        end)
      end)
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

    local function get_explorer_item_at_mouse(explorer, mouse)
      if not explorer or not explorer.list or not explorer.list.win or mouse.winid ~= explorer.list.win.win then
        return nil
      end

      local idx = explorer.list:row2idx(mouse.line)
      if idx < 1 or idx > explorer.list:count() then
        return nil
      end

      return explorer:resolve(explorer.list:get(idx))
    end

    local function dir_for_item(item)
      if not item or not item.file then
        return nil
      end

      return item.dir and item.file or vim.fs.dirname(item.file)
    end

    local file_menu_items = {
      { name = "复制当前文件地址", cmd = menu_action(utils.copy_current_file_path_from_tcd), rtxt = "yf" },
      { name = "复制当前文件所在目录", cmd = menu_action(utils.copy_current_file_dir_from_tcd), rtxt = "yd" },
      { name = "Git Blame", cmd = menu_action("Gitsigns blame"), rtxt = "git" },
      { name = "Diff This", cmd = menu_action(utils.diff_current_file), rtxt = "HEAD" },
      { name = "File History", cmd = menu_action("CodeDiff history %"), rtxt = "Hist" },
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
        local item = get_explorer_item_at_mouse(explorer, mouse) or explorer:current()
        local target_dir = dir_for_item(item) or explorer:dir()
        local explorer_menu_items = {
          {
            name = "复制目录地址",
            cmd = menu_action(function()
              utils.copy_dir_from_tcd(target_dir)
            end),
            rtxt = "yd",
          },
          {
            name = "搜索此目录中的文件内容",
            cmd = picker_menu_action("grep", function()
              Snacks.picker.grep({ cwd = target_dir })
            end),
            rtxt = "grep",
          },
          {
            name = "搜索此目录中的文件名",
            cmd = picker_menu_action("files", function()
              Snacks.picker.files({ cwd = target_dir })
            end),
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
