return {
  "dlyongemallo/diffview-plus.nvim",
  version = "*",
  -- optional: lazy-load on command
  -- cmd = {
  --     "DiffviewOpen",
  --     "DiffviewToggle",
  --     "DiffviewFileHistory",
  --     "DiffviewDiffFiles",
  --     "DiffviewLog",
  -- },
  config = function ()
    require("diffview").setup({
      view = {
        merge_tool = {
          layout = "diff4_mixed",
          disable_diagnostics = true,
          winbar_info = true,
        },
        cycle_layouts = {
          merge_tool = { "diff4_mixed", "diff3_mixed", "diff3_horizontal", "diff1_plain" },
        },
      },
    })
  end
}
