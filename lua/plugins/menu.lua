return {
  "nvzone/menu",
  dependencies = {
    "nvzone/volt",
    "nvim-tree/nvim-web-devicons",
  },
  config = function()
    local utils = require("utils")
    local menu = require("menu")
    local menu_state = require("menu.state")
    local volt = require("volt")
    local volt_utils = require("volt.utils")
    local close_group = vim.api.nvim_create_augroup("tcstory_menu_close", { clear = true })

    local function menu_is_open()
      if #menu_state.bufids > 0 then
        return true
      end

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "NvMenu" then
          return true
        end
      end

      return false
    end

    local function collect_menu_bufs()
      local seen = {}
      local bufs = {}

      local function add(buf)
        if buf and vim.api.nvim_buf_is_valid(buf) and not seen[buf] then
          seen[buf] = true
          table.insert(bufs, buf)
        end
      end

      for _, buf in ipairs(menu_state.bufids) do
        add(buf)
      end

      for buf, _ in pairs(menu_state.bufs or {}) do
        add(buf)
      end

      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "NvMenu" then
          add(buf)
        end
      end

      return bufs
    end

    local function clear_menu_close_hooks()
      pcall(vim.api.nvim_del_augroup_by_id, close_group)
      close_group = vim.api.nvim_create_augroup("tcstory_menu_close", { clear = true })

      for _, mode in ipairs({ "n", "x", "s", "o" }) do
        pcall(vim.keymap.del, mode, "<LeftMouse>")
      end
    end

    do
      local original_volt_close = volt.close

      volt.close = function(buf)
        if not buf then
          return original_volt_close()
        end

        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end

        local filetype = vim.bo[buf].filetype
        if filetype ~= "NvMenu" and filetype ~= "VoltWindow" then
          return original_volt_close(buf)
        end

        local bufs = filetype == "NvMenu" and collect_menu_bufs() or { buf }
        if #bufs == 0 then
          return
        end

        volt_utils.close({
          bufs = bufs,
          after_close = function()
            if filetype == "NvMenu" then
              menu_state.bufs = {}
              menu_state.config = nil
              menu_state.nested_menu = ""
              menu_state.bufids = {}
            end
          end,
        })
      end
    end

    local function close_menu()
      if not menu_is_open() then
        clear_menu_close_hooks()
        return
      end

      local old_win = menu_state.old_data and menu_state.old_data.win
      local old_cursor = menu_state.old_data and menu_state.old_data.cursor
      local bufs = collect_menu_bufs()

      if #bufs == 0 then
        clear_menu_close_hooks()
        return
      end

      volt_utils.close({
        bufs = bufs,
        after_close = function()
          menu_state.bufs = {}
          menu_state.config = nil
          menu_state.nested_menu = ""
          menu_state.bufids = {}

          if old_win and vim.api.nvim_win_is_valid(old_win) then
            vim.api.nvim_set_current_win(old_win)

            if old_cursor then
              vim.schedule(function()
                pcall(vim.api.nvim_win_set_cursor, old_win, {
                  math.max(1, old_cursor[1]),
                  math.max(0, old_cursor[2]),
                })
              end)
            end
          end
        end,
      })

      vim.schedule(function()
        if not menu_is_open() then
          clear_menu_close_hooks()
        end
      end)
    end

    local function close_menu_if_clicked_outside()
      if not menu_is_open() then
        clear_menu_close_hooks()
        return
      end

      local mouse = vim.fn.getmousepos()
      if mouse.winid == 0 or not vim.api.nvim_win_is_valid(mouse.winid) then
        close_menu()
        return
      end

      local buf = vim.api.nvim_win_get_buf(mouse.winid)
      if vim.bo[buf].filetype ~= "NvMenu" then
        close_menu()
      end
    end

    local function install_menu_close_hooks()
      clear_menu_close_hooks()

      vim.api.nvim_create_autocmd({ "ModeChanged", "WinClosed", "BufLeave" }, {
        group = close_group,
        callback = function()
          if not menu_is_open() then
            clear_menu_close_hooks()
          end
        end,
      })

      for _, mode in ipairs({ "n", "x", "s", "o" }) do
        vim.keymap.set(mode, "<LeftMouse>", function()
          vim.cmd.exec('"normal! \\<LeftMouse>"')
          vim.schedule(close_menu_if_clicked_outside)
        end, { silent = true, nowait = true, desc = "Close context menu on outside click" })
      end
    end

    local function install_menu_buffer_hooks()
      for _, buf in ipairs(collect_menu_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.keymap.set("n", "<LeftMouse>", function()
            close_menu_soon()
          end, { buffer = buf, silent = true, nowait = true, desc = "Close context menu after click" })
        end
      end
    end

    local function open_menu(items)
      menu.open(items, { mouse = true })
      install_menu_close_hooks()
      vim.schedule(install_menu_buffer_hooks)
    end

    local function close_menu_soon()
      vim.schedule(close_menu)

      for _, delay in ipairs({ 20, 60, 120, 220 }) do
        vim.defer_fn(close_menu, delay)
      end
    end

    local function is_normal_file_buffer(buf)
      return vim.bo[buf].buftype == "" and vim.api.nvim_buf_get_name(buf) ~= ""
    end

    local function menu_action(cmd)
      return function()
        vim.schedule(function()
          close_menu_soon()

          if type(cmd) == "string" then
            vim.cmd(cmd)
          else
            cmd()
          end

          close_menu_soon()
        end)
      end
    end

    local function file_history_action()
      return menu_action(function()
        local file = vim.api.nvim_buf_get_name(0)
        if file == "" or vim.bo.buftype ~= "" then
          vim.notify("File History 仅支持普通文件缓冲区", vim.log.levels.WARN)
          return
        end

        require("lazy").load({ plugins = { "diffview.nvim" } })
        vim.cmd("DiffviewFileHistory %")
      end)
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
      { name = "File History", cmd = file_history_action(), rtxt = "Hist" },
    }

    vim.keymap.set({ "n", "v" }, "<RightMouse>", function()
      close_menu()

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

        open_menu(explorer_menu_items)
        return
      end

      if not is_normal_file_buffer(buf) then
        return
      end

      open_menu(file_menu_items)
    end, { desc = "Open context menu" })
  end,
}
