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

    local menu_items = {
      { name = "复制当前文件地址", cmd = utils.copy_current_file_path_from_tcd, rtxt = "yf" },
      { name = "复制当前文件所在目录", cmd = utils.copy_current_file_dir_from_tcd, rtxt = "yd" },
      { name = "Diff This", cmd = function() require("gitsigns").diffthis() end, rtxt = "gd" },
    }

    vim.keymap.set({ "n", "v" }, "<RightMouse>", function()
      require("menu.utils").delete_old_menus()

      vim.cmd.exec('"normal! \\<RightMouse>"')

      local mouse = vim.fn.getmousepos()
      local buf = mouse.winid ~= 0 and vim.api.nvim_win_get_buf(mouse.winid) or vim.api.nvim_get_current_buf()

      if not is_normal_file_buffer(buf) then
        return
      end

      require("menu").open(menu_items, { mouse = true })
    end, { desc = "Open context menu" })
  end,
}
