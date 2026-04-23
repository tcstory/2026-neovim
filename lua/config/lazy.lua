-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"

  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.opt.number = true
vim.opt.list = true
vim.opt.listchars = 'extends:❯,precedes:❮,tab:▸ ,trail:˽'
vim.opt.smartindent = true
vim.opt.expandtab = true
vim.opt.termguicolors = true
vim.opt.updatetime = 1000
vim.opt.autoread = false
vim.opt.clipboard = vim.opt.clipboard + 'unnamedplus'
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.cursorline = true
vim.opt.fillchars = {
  eob = " ",
  fold = " ",
  foldopen = "",
  foldsep = " ",
  foldclose = "",
}

vim.keymap.set("n", "<leader>w-", "<cmd>split<cr>", { desc = "Split Down" })
vim.keymap.set("n", "<leader>w|", "<cmd>vsplit<cr>", { desc = "Split Right" })
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Terminal Normal Mode" })
vim.keymap.set("n", "q", "<Nop>", { silent = true, desc = "Disable Macro Recording" })
vim.keymap.set("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
vim.keymap.set("n", "<leader>bb", "<cmd>buffer#<cr>", { desc = "Last Buffer" })
local function delete_buffer_keep_windows(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local wins = vim.fn.win_findbuf(bufnr)
  local replacement = vim.fn.bufnr("#")

  if replacement == bufnr or replacement == -1 or vim.fn.buflisted(replacement) == 0 then
    replacement = nil

    for _, candidate in ipairs(vim.api.nvim_list_bufs()) do
      if candidate ~= bufnr and vim.fn.buflisted(candidate) == 1 then
        replacement = candidate
        break
      end
    end
  end

  if not replacement then
    vim.cmd("enew")
    replacement = vim.api.nvim_get_current_buf()
  end

  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_buf(win, replacement)
    end
  end

  vim.api.nvim_buf_delete(bufnr, {})
end

vim.keymap.set("n", "<leader>bd", function()
  delete_buffer_keep_windows()
end, { desc = "Delete Buffer" })
vim.keymap.set("n", "<leader>bo", function()
  local current = vim.api.nvim_get_current_buf()

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if bufnr ~= current and vim.api.nvim_buf_is_loaded(bufnr) then
      local bo = vim.bo[bufnr]
      if bo.buftype == "" then
        pcall(vim.api.nvim_buf_delete, bufnr, {})
      end
    end
  end
end, { desc = "Delete Other Buffers" })
vim.keymap.set("n", "<leader>ba", function()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local bo = vim.bo[bufnr]
      if bo.buftype == "" then
        pcall(vim.api.nvim_buf_delete, bufnr, {})
      end
    end
  end
end, { desc = "Delete All Buffers" })
vim.keymap.set("n", "<leader>bc", "<cmd>enew<cr>", { desc = "New Buffer" })
vim.keymap.set("n", "<leader>bl", function() Snacks.picker.buffers() end, { desc = "List Buffers" })

local autosave_group = vim.api.nvim_create_augroup("tcstory_autosave", { clear = true })
local checktime_group = vim.api.nvim_create_augroup("tcstory_checktime", { clear = true })
local fcitx_terminal_group = vim.api.nvim_create_augroup("tcstory_fcitx_terminal", { clear = true })

local function autosave_buffer(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)

  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].modifiable == false or vim.bo[bufnr].readonly then
    return
  end

  if name == "" or vim.bo[bufnr].modified == false then
    return
  end

  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("silent update")
  end)
end

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  group = autosave_group,
  callback = function(args)
    autosave_buffer(args.buf)
  end,
})

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
  group = checktime_group,
  callback = function()
    if vim.fn.mode() == "c" then
      return
    end
    vim.cmd("checktime")
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = fcitx_terminal_group,
  pattern = "t:*",
  callback = function()
    if vim.bo.buftype == "terminal" and _G._Fcitx2en then
      _G._Fcitx2en()
    end
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = fcitx_terminal_group,
  pattern = "*:t",
  callback = function()
    if vim.bo.buftype == "terminal" and _G._Fcitx2NonLatin then
      _G._Fcitx2NonLatin()
    end
  end,
})

local function put_with_reindent(keys)
  vim.cmd.normal({ keys, bang = true })
  local view = vim.fn.winsaveview()
  vim.cmd([[silent! normal! `[v`]=]])
  vim.fn.winrestview(view)
end

local function put_keys(keys)
  local register = vim.v.register
  local count = vim.v.count
  local prefix = ""

  if register ~= nil and register ~= "" and register ~= '"' then
    prefix = prefix .. '"' .. register
  end

  if count > 0 then
    prefix = prefix .. count
  end

  return prefix .. keys
end

local function paste_with_reindent()
  put_with_reindent('"+p')
end

vim.keymap.set("n", "p", function()
  put_with_reindent(put_keys("p"))
end, { desc = "Paste with Reindent" })

vim.keymap.set("n", "P", function()
  put_with_reindent(put_keys("P"))
end, { desc = "Paste Before with Reindent" })

local function paste_to_terminal()
  local text = vim.fn.getreg("+")
  local job = vim.b.terminal_job_id

  if text == "" then
    return
  end

  if not job then
    vim.notify("Current buffer is not an active terminal", vim.log.levels.WARN)
    return
  end

  vim.api.nvim_chan_send(job, text)
end

if vim.g.neovide then
    -- 核心配置：英文在前，中文在后，最后是字号
    -- 如果你的字体路径或名字有空格，这里用逗号隔开即可
    vim.opt.guifont = "BlexMono Nerd Font Mono,LXGW WenKai:h12"

    -- 针对霞鹜文楷的微调（可选）
    -- 1. 调整行高：文楷的字形偏大，如果觉得太挤，可以加一点间距
    -- vim.opt.linespace = 2

    -- 2. 渲染平滑度：Neovide 独有设置
    vim.g.neovide_font_hinting = "full" -- 让字体看起来更锐利

    vim.keymap.set({ "n", "v" }, "<C-S-c>", '"+y', { desc = "Copy to Clipboard" })
    vim.keymap.set("i", "<C-S-v>", function()
      local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
      vim.api.nvim_feedkeys(esc, "nx", false)
      vim.schedule(function()
        paste_with_reindent()
        vim.cmd.startinsert()
      end)
    end, { desc = "Paste from Clipboard" })
    vim.keymap.set("c", "<C-S-v>", "<C-r>+", { desc = "Paste from Clipboard" })
    vim.keymap.set("n", "<C-S-v>", paste_with_reindent, { desc = "Paste from Clipboard" })
    vim.keymap.set("v", "<C-S-v>", '"+p', { desc = "Paste from Clipboard" })
    vim.keymap.set("t", "<C-S-v>", paste_to_terminal, { desc = "Paste from Clipboard" })
end

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
    -- import your plugins
    { import = "plugins" },
  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = false },
})
