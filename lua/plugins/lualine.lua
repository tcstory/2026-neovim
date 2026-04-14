return {
  'nvim-lualine/lualine.nvim',
  dependencies = { 'nvim-tree/nvim-web-devicons' },
  config = function()
    local utils = require("utils")

    local function shorten_path(path, max_len)
      if #path <= max_len then
        return path
      end

      local parts = vim.split(path, '/', { plain = true })
      if #parts <= 1 then
        return path
      end

      for i = 1, #parts - 1 do
        if #path <= max_len then
          break
        end

        if parts[i] ~= '' and parts[i] ~= '.' and parts[i] ~= '..' then
          parts[i] = parts[i]:sub(1, 1)
          path = table.concat(parts, '/')
        end
      end

      if #path <= max_len then
        return path
      end

      return '.../' .. table.concat({ unpack(parts, math.max(1, #parts - 2), #parts) }, '/')
    end

    local function parent_and_file(path)
      local parts = vim.split(path, '/', { plain = true })
      if #parts <= 1 then
        return path
      end

      return table.concat({ parts[#parts - 1], parts[#parts] }, '/')
    end

    local function file_path_status()
      local file = vim.api.nvim_buf_get_name(0)
      if file == '' then
        return '[No Name]'
      end

      local cwd = utils.tab_or_global_cwd()
      local relative = vim.fs.relpath(cwd, file)
      local path = relative or vim.fn.fnamemodify(file, ':~')
      local winwidth = vim.fn.winwidth(0)
      local total_width = vim.o.columns
      local width_ratio = winwidth / math.max(total_width, 1)

      if winwidth < 70 or width_ratio < 0.35 then
        return vim.fn.fnamemodify(file, ':t')
      end

      if winwidth < 140 or width_ratio < 0.6 then
        return parent_and_file(path)
      end

      local max_len = math.max(30, math.floor(winwidth * 0.45))

      return shorten_path(path, max_len)
    end

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
        -- theme = "tokyonight",
        component_separators = { left = '|', right = '|' },
        section_separators = { left = '', right = '' },
      },
      sections = {
        lualine_c = {
          file_path_status,
        },
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
