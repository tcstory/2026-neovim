return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    local autosave = require('config.autosave')

    require('lualine').setup({
      sections = {
        lualine_a = {
          {
            'lsp_status',
            icon = '', -- f013
            symbols = {
              -- Standard unicode symbols to cycle through for LSP progress:
              spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' },
              -- Standard unicode symbol for when LSP is done:
              done = '✓',
              -- Delimiter inserted between LSP names:
              separator = ' ',
            },
            -- List of LSP names to ignore (e.g., `null-ls`):
            ignore_lsp = {},
            -- Display the LSP name
            show_name = true,
          },
        },
        lualine_x = {
          {
            function()
              return '󰄬 Auto'
            end,
            cond = function()
              return autosave.is_eligible(0)
            end,
          },
          'encoding',
          'fileformat',
          'filetype',
        },
      },
    })
  end,
}
