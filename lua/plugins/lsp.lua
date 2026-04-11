return {
  -- 1. 为 Neovim Lua 开发提供增强（写插件必备）
  { "folke/lazydev.nvim", ft = "lua", opts = {} },
  {
    'saghen/blink.cmp',
    version = '1.*',
    opts = {
      keymap = { preset = 'default' },
      sources = {
        default = { 'lsp', 'path', 'snippets', 'buffer' },
      },
    },
  },

  -- 2. LSP 核心链
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim", -- 可选：自动安装 linter/formatter
    },
    config = function()
      -- 开启 Mason
      require("mason").setup()

      -- 配置需要自动安装的服务端（根据你的 JS/TS 需求）
      local servers = {
        vtsls = {}, -- 替代传统的 tsserver，更现代的 TS 支持
        lua_ls = {}, -- Lua 支持
        html = {},
        cssls = {},
        somesass_ls = {},
      }

      require("mason-lspconfig").setup({
        ensure_installed = vim.tbl_keys(servers),
        handlers = {
          function(server_name)
            local server = servers[server_name] or {}
            -- 这里的 setup 会把 LSP 关联到 Neovim
            require("lspconfig")[server_name].setup(server)
          end,
        },
      })

      -- 自定义 LSP 快捷键（结合你的 Snacks.picker 提升体验）
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          local opts = { buffer = args.buf }

          -- 使用 Snacks 替代原生的跳转，界面更漂亮
          vim.keymap.set("n", "gd", function() Snacks.picker.lsp_definitions() end, opts)
          vim.keymap.set("n", "gr", function() Snacks.picker.lsp_references() end, opts)
          vim.keymap.set("n", "gi", function() Snacks.picker.lsp_implementations() end, opts)
          vim.keymap.set("n", "gt", function() Snacks.picker.lsp_type_definitions() end, opts)

          -- 代码操作和重命名
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

          -- 悬浮文档
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
        end,
      })
    end,
  },
}
