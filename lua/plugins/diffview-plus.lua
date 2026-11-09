return {
  "tcstory/diffview-plus.nvim",
  commit = "712430437db4edc605236723ae0f6bf8ef21d28c",
  name = "diffview-plus.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons" },
  cmd = {
    "DiffviewOpen",
    "DiffviewMergeOpen",
    "DiffviewToggle",
    "DiffviewFileHistory",
    "DiffviewDiffFiles",
    "DiffviewMergeFiles",
    "DiffviewDiffDirs",
    "DiffviewLog",
    "DiffviewClose",
    "DiffviewFocusFiles",
    "DiffviewToggleFiles",
    "DiffviewRefresh",
  },
  config = function()
    require("diffview").setup({
      file_history_panel = {
        log_options = {
          git = {
            single_file = {
              follow = true,
              diff_merges = "off",
            },
            multi_file = {
              diff_merges = "off",
            },
          },
        },
      },
      view = {
        merge_tool = {
          layout = "diff3_horizontal",
          disable_diagnostics = true,
          winbar_info = true,
        },
        cycle_layouts = {
          merge_tool = { "diff4_mixed", "diff3_mixed", "diff3_horizontal", "diff1_plain" },
        },
      },
    })
  end,
}
