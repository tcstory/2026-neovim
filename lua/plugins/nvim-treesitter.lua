return {
  "nvim-treesitter/nvim-treesitter", 
  branch = 'master', 
  lazy = false, 
  build = ":TSUpdate",
  main = "nvim-treesitter.configs", -- 告诉 lazy.nvim 自动调用 require("nvim-treesitter.configs").setup(opts)
  opts = {
    -- LazyVim config for treesitter
    indent = { enable = true }, ---@type lazyvim.TSFeat
    highlight = { enable = true }, ---@type lazyvim.TSFeat
    folds = { enable = true }, ---@type lazyvim.TSFeat
    ensure_installed = {
      "vim",
      "regex",
      "bash",
      "jsdoc",
      "json",
      "jsonc",
      "lua",
      "luadoc",
      "luap",
      "markdown",
      "markdown_inline",
      "javascript",
      "typescript",
      "vue",
      "css",
      "scss",
      "html",
    },
  },
}
