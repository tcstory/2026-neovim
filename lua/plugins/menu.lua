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

local function get_file_menu_items()
  return {
    { text = "复制当前文件地址", action = utils.copy_current_file_path_from_tcd, shortcut = "yf" },
    { text = "复制当前文件所在目录", action = utils.copy_current_file_dir_from_tcd, shortcut = "yd" },
    { text = "Git Blame", action = function() vim.cmd("Gitsigns blame") end, shortcut = "git" },
    { text = "Diff This", action = utils.diff_current_file, shortcut = "HEAD" },
    { text = "File History", action = file_history_action(), shortcut = "Hist" },
  }
end

local function setup_file_menu()
  vim.keymap.set({ "n", "v" }, "<RightMouse>", function()
    vim.cmd.exec('"normal! \\<RightMouse>"')

    local mouse = vim.fn.getmousepos()
    local buf = mouse.winid ~= 0 and vim.api.nvim_win_get_buf(mouse.winid) or vim.api.nvim_get_current_buf()
    local winid = mouse.winid ~= 0 and mouse.winid or vim.api.nvim_get_current_win()

    if not is_normal_file_buffer(buf) then
      return
    end

    if vim.api.nvim_win_is_valid(winid) then
      vim.api.nvim_set_current_win(winid)
    end

    local filename = vim.fs.basename(vim.api.nvim_buf_get_name(buf))
    utils.open_in_place_menu(filename, get_file_menu_items())
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
