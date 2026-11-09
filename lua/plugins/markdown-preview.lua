return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  ft = { "markdown" },
  build = function()
    vim.fn["mkdp#util#install"]()
  end,
  init = function()
    -- 禁用光标同步滚动，保持浏览器页面稳定不随光标乱跳
    vim.g.mkdp_sync_scroll = 0
    -- 关闭 Neovim buffer 时不自动强制关闭浏览器网页
    vim.g.mkdp_auto_close = 0
    -- 页面标题使用文档文件名
    vim.g.mkdp_page_title = "${name}"
  end,
  keys = {
    {
      "<leader>mp",
      "<cmd>MarkdownPreviewToggle<cr>",
      desc = "Markdown Preview (Browser)",
      ft = "markdown",
    },
  },
}
