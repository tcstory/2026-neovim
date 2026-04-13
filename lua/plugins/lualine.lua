return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    local function lsp_status()
      local bufnr = vim.api.nvim_get_current_buf()
      local clients = vim.lsp.get_clients({ bufnr = bufnr })
      if #clients == 0 then
        return 'no-lsp'
      end

      local names = {}
      for _, client in ipairs(clients) do
        names[#names + 1] = client.name
      end
      return 'lsp:' .. table.concat(names, ',')
    end

    require('lualine').setup({
      options = {
        theme = "tokyonight",
        component_separators = { left = '|', right = '|' },
        section_separators = { left = '', right = '' },
      },
      sections = {
        lualine_x = {
          lsp_status,
          'encoding',
          'fileformat',
          'filetype',
        },
      },
    })
  end,
}
