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

local function ensure_node_in_path()
  if vim.fn.executable("node") == 1 then
    return
  end

  local candidates = {}
  local home = vim.fn.expand("~")
  local sep = package.config:sub(1, 1)

  local function add(path)
    if path and path ~= "" then
      table.insert(candidates, path)
    end
  end

  add(vim.env.NVM_BIN)
  add(home .. "/.volta/bin")
  add(home .. "/.asdf/shims")
  add(home .. "/.local/share/mise/shims")
  add(home .. "/.fnm")

  local nvm_bins = vim.fn.glob(home .. "/.nvm/versions/node/*/bin", false, true)
  table.sort(nvm_bins)
  for i = #nvm_bins, 1, -1 do
    add(nvm_bins[i])
  end

  for _, dir in ipairs(candidates) do
    local node = dir .. sep .. "node"
    if vim.fn.executable(node) == 1 then
      vim.env.PATH = dir .. ":" .. (vim.env.PATH or "")
      return
    end
  end
end

ensure_node_in_path()

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
