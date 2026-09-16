return {
  'akinsho/bufferline.nvim',
  version = "*",
  event = "VeryLazy",
  dependencies = {
    'nvim-tree/nvim-web-devicons',
    'folke/tokyonight.nvim',
  },
  keys = {
    { "<leader>bn", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
    { "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev Buffer" }, 
  },
  config = function()
    local ok, c = pcall(function()
      return require("tokyonight.colors").setup()
    end)

    local selected_bg = ok and c.bg_visual or "#2e3c64"
    local inactive_bg = ok and c.bg_dark or "#1f2335"
    local fill_bg = ok and c.bg_dark1 or "#1b1e2d"
    local active_fg = "#ffffff"
    local inactive_fg = ok and c.fg_dark or "#7982a9"
    local accent = ok and c.blue or "#7aa2f7"
    local warn = ok and c.warning or "#e0af68"

    require('bufferline').setup({
      options = {
        indicator = {
          style = "underline",
        },
        offsets = {
          {
            filetype = "snacks_layout_box",
            text = "Explorer",
            text_align = "left",
            separator = true,
          },
        },
      },
      highlights = {
        fill = {
          bg = fill_bg,
        },
        background = {
          fg = inactive_fg,
          bg = inactive_bg,
        },
        buffer_selected = {
          fg = active_fg,
          bg = selected_bg,
          bold = true,
          italic = false,
        },
        buffer_visible = {
          fg = inactive_fg,
          bg = inactive_bg,
        },
        close_button = {
          fg = inactive_fg,
          bg = inactive_bg,
        },
        close_button_selected = {
          fg = accent,
          bg = selected_bg,
        },
        close_button_visible = {
          fg = inactive_fg,
          bg = inactive_bg,
        },
        indicator_selected = {
          fg = accent,
          bg = selected_bg,
        },
        modified = {
          fg = warn,
          bg = inactive_bg,
        },
        modified_selected = {
          fg = warn,
          bg = selected_bg,
        },
        modified_visible = {
          fg = warn,
          bg = inactive_bg,
        },
        separator = {
          fg = fill_bg,
          bg = inactive_bg,
        },
        separator_selected = {
          fg = fill_bg,
          bg = selected_bg,
        },
        separator_visible = {
          fg = fill_bg,
          bg = inactive_bg,
        },
      },
    })
  end,
}
