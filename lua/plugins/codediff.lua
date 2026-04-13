return {
  "esmuellert/codediff.nvim",
  cmd = "CodeDiff",
  opts = {
    explorer = {
      view_mode = "tree"
    }
  },
  config = function(_, opts)
    require("codediff").setup(opts)

    local function get_codediff_session(tabpage)
      local ok, lifecycle = pcall(require, "codediff.ui.lifecycle")
      if not ok or not lifecycle.get_session then
        return nil
      end
      return lifecycle.get_session(tabpage)
    end

    local function get_codediff_buffers(tabpage)
      local session = get_codediff_session(tabpage)
      if not session then
        return {}
      end

      local buffers = {}
      if session.original_bufnr and vim.api.nvim_buf_is_valid(session.original_bufnr) then
        buffers[session.original_bufnr] = true
      end
      if session.modified_bufnr and vim.api.nvim_buf_is_valid(session.modified_bufnr) then
        buffers[session.modified_bufnr] = true
      end
      if session.result_bufnr and vim.api.nvim_buf_is_valid(session.result_bufnr) then
        buffers[session.result_bufnr] = true
      end
      return buffers
    end

    local function disable_lsp_for_codediff(tabpage)
      for bufnr in pairs(get_codediff_buffers(tabpage)) do
        vim.b[bufnr].codediff_disable_lsp = true
        vim.diagnostic.enable(false, { bufnr = bufnr })
        if vim.lsp.inlay_hint then
          pcall(vim.lsp.inlay_hint.enable, false, { bufnr = bufnr })
        end
        for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
          vim.lsp.buf_detach_client(bufnr, client.id)
        end
      end
    end

    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeDiffOpen",
      callback = function(args)
        local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
        disable_lsp_for_codediff(tabpage)
      end,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeDiffFileSelect",
      callback = function(args)
        local tabpage = args.data and args.data.tabpage or vim.api.nvim_get_current_tabpage()
        vim.schedule(function()
          if vim.api.nvim_tabpage_is_valid(tabpage) then
            disable_lsp_for_codediff(tabpage)
          end
        end)
      end,
    })

    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
      callback = function()
        local tabpage = vim.api.nvim_get_current_tabpage()
        if get_codediff_session(tabpage) then
          disable_lsp_for_codediff(tabpage)
        end
      end,
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        if not vim.b[args.buf].codediff_disable_lsp then
          return
        end

        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(args.buf) then
            return
          end

          vim.diagnostic.enable(false, { bufnr = args.buf })
          if vim.lsp.inlay_hint then
            pcall(vim.lsp.inlay_hint.enable, false, { bufnr = args.buf })
          end

          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client then
            vim.lsp.buf_detach_client(args.buf, client.id)
          end
        end)
      end,
    })
  end,
}
