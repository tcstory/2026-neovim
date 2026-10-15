return {
  "gbprod/nord.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    transparent = false,
    terminal_colors = true,
    diff = { mode = "fg" },
    borders = true,
    errors = { mode = "bg" },
    styles = {
      comments = { italic = true },
    },
    on_highlights = function(highlights, c)
      -- 突出 Diff 中的字符级精确变动与面板选中文件
      highlights.DiffText = { fg = c.snow_storm.brightest, bg = c.frost.artic_ocean, bold = true }
      highlights.DiffviewFilePanelSelected = { fg = c.frost.ice, bold = true }
    end,
  },
  config = function(_, opts)
    require("nord").setup(opts)
    vim.cmd.colorscheme("nord")
  end,
}
