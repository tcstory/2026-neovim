return {
  "rebelot/kanagawa.nvim",
  priority = 1000,
  config = function()
    local is_neovide = vim.g.neovide == true

    require("kanagawa").setup({
      theme = "dragon",
      transparent = false,
      dimInactive = is_neovide,
      terminalColors = true,
      colors = is_neovide and {
        theme = {
          all = {
            ui = {
              bg_gutter = "none",
            },
          },
        },
      } or nil,
      overrides = function(colors)
        if not is_neovide then
          return {}
        end

        local palette = colors.palette
        local theme = colors.theme
        local color = require("kanagawa.lib.color")
        local function diagnostic_background(foreground)
          return {
            fg = foreground,
            bg = color(foreground):blend(theme.ui.bg, 0.92):to_hex(),
          }
        end

        return {
          CursorLine = { bg = theme.ui.bg_p1 },
          WinSeparator = { fg = palette.dragonBlack5 },
          Visual = { bg = theme.ui.bg_visual },

          NormalFloat = { fg = theme.ui.float.fg, bg = theme.ui.float.bg, blend = 10 },
          FloatBorder = { fg = palette.dragonBlue2, bg = theme.ui.float.bg, blend = 10 },
          FloatTitle = { fg = palette.dragonYellow, bg = theme.ui.float.bg, bold = true, blend = 10 },

          Pmenu = { fg = theme.ui.pmenu.fg, bg = theme.ui.pmenu.bg, blend = 6 },
          PmenuSel = { fg = theme.ui.pmenu.fg_sel, bg = theme.ui.pmenu.bg_sel, bold = true },
          PmenuSbar = { bg = theme.ui.pmenu.bg_sbar },
          PmenuThumb = { bg = theme.ui.pmenu.bg_thumb },

          DiagnosticVirtualTextHint = diagnostic_background(theme.diag.hint),
          DiagnosticVirtualTextInfo = diagnostic_background(theme.diag.info),
          DiagnosticVirtualTextWarn = diagnostic_background(theme.diag.warning),
          DiagnosticVirtualTextError = diagnostic_background(theme.diag.error),
        }
      end,
    })

    vim.cmd("colorscheme kanagawa-dragon")
  end,
}
