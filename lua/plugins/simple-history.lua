return {
  -- dir 指向你刚才创建插件的物理路径
  dir = "~/Documents/Coding/lua/local-history.nvim",
  name = "local-history",
  -- 1. 添加事件触发，让它在读取文件或新建文件时自动加载
  event = { "BufReadPost", "BufNewFile" },
  -- 2. 显式设置 lazy = false 确保它在事件发生时立即运行
  lazy = false, 
  config = function()
    require("local-history").setup({
      silent = false -- 开启提示，这样你一打开文件就能看到它生效了
    })
  end,
  keys = {
    { "<leader>su", "<cmd>LocalHistoryCheck<cr>", desc = "Local History" },
  },
}
