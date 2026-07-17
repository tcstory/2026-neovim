return {
  "romus204/tree-sitter-manager.nvim",
  dependencies = {}, -- tree-sitter CLI must be installed system-wide
  config = function()
    require("tree-sitter-manager").setup({
      ensure_installed = {
        "vim",
        "regex",
        "bash",
        "jsdoc",
        "json",
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
    })
  end,
}
