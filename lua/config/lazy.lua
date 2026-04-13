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

vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit Window" })

local autosave_group = vim.api.nvim_create_augroup("tcstory_autosave", { clear = true })
local checktime_group = vim.api.nvim_create_augroup("tcstory_checktime", { clear = true })

vim.api.nvim_create_autocmd("InsertLeave", {
  group = autosave_group,
  callback = function(args)
    local bufnr = args.buf
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
    vim.keymap.set("i", "<C-S-v>", "<C-r>+", { desc = "Paste from Clipboard" })
    vim.keymap.set("c", "<C-S-v>", "<C-r>+", { desc = "Paste from Clipboard" })
    vim.keymap.set("n", "<C-S-v>", '"+p', { desc = "Paste from Clipboard" })
    vim.keymap.set("v", "<C-S-v>", '"+p', { desc = "Paste from Clipboard" })
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
