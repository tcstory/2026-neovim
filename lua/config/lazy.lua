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
vim.opt.autoread = true
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

-- 原生 Treesitter 折叠 (Neovim 0.10+)
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = ""
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
vim.opt.foldenable = true

vim.keymap.set("n", "zR", function() vim.opt.foldlevel = 99 end, { desc = "Open All Folds" })
vim.keymap.set("n", "zM", function() vim.opt.foldlevel = 0 end, { desc = "Close All Folds" })

vim.keymap.set("n", "<leader>w-", "<cmd>split<cr>", { desc = "Split Down" })
vim.keymap.set("n", "<leader>w|", "<cmd>vsplit<cr>", { desc = "Split Right" })
vim.keymap.set("t", "<Esc><Esc>", [[<C-\><C-n>]], { desc = "Terminal Normal Mode" })
vim.keymap.set("n", "q", "<Nop>", { silent = true, desc = "Disable Macro Recording" })
vim.keymap.set("n", "]b", "<cmd>bnext<cr>", { desc = "Next Buffer" })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
vim.keymap.set("n", "<leader>bn", "<cmd>bnext<cr>", { desc = "Next Buffer" })
vim.keymap.set("n", "<leader>bp", "<cmd>bprevious<cr>", { desc = "Previous Buffer" })
vim.keymap.set("n", "<leader>tq", "<cmd>tabclose<cr>", { desc = "Close Tab" })
vim.keymap.set("n", "<leader>bd", function() Snacks.bufdelete() end, { desc = "Delete Buffer" })
vim.keymap.set("n", "<leader>bo", function() Snacks.bufdelete.other() end, { desc = "Delete Other Buffers" })
vim.keymap.set("n", "<leader>ba", function() Snacks.bufdelete.all() end, { desc = "Delete All Buffers" })
vim.keymap.set("n", "<leader>bc", "<cmd>enew<cr>", { desc = "New Buffer" })
vim.keymap.set("n", "<leader>bl", function() Snacks.picker.buffers() end, { desc = "List Buffers" })
vim.keymap.set("n", "<leader>bs", "<cmd>update<cr>", { desc = "Save Buffer" })

local checktime_group = vim.api.nvim_create_augroup("tcstory_checktime", { clear = true })
local fcitx_terminal_group = vim.api.nvim_create_augroup("tcstory_fcitx_terminal", { clear = true })

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

vim.keymap.set("n", "p", function()
  put_with_reindent(put_keys("p"))
end, { desc = "Paste with Reindent" })

vim.keymap.set("n", "P", function()
  put_with_reindent(put_keys("P"))
end, { desc = "Paste Before with Reindent" })

require("config.neovide")

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
