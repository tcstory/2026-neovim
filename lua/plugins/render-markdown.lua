return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  ft = { "markdown" },
  opts = {
    file_types = { "markdown" },
    -- 严格遵守不修改/不修饰标题的原则：
    -- 彻底清空图标与 emoji，不使用图标区分任务等级
    heading = {
      enabled = true,
      sign = false,
      icons = {}, -- 彻底清空图标
      position = "inline",
    },
    -- 启用干净优雅的复选框 (- [ ] / - [X]) 渲染
    checkbox = {
      enabled = true,
      position = "inline",
    },
    -- 启用平滑圆角对齐表格
    table = {
      enabled = true,
      style = "full",
    },
    pipe_table = {
      enabled = true,
      style = "full",
    },
    -- 启用代码块卡片
    code = {
      enabled = true,
      sign = false,
      style = "full",
    },
    -- 启用无序列表项目符号的轻量规整（可按需保留）
    bullet = {
      enabled = true,
    },
  },
}
