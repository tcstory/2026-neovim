return {
  -- 1. 为 Neovim Lua 开发提供增强（写插件必备）
  { "folke/lazydev.nvim", ft = "lua", opts = {} },
  {
    'saghen/blink.cmp',
    version = '1.*',
    opts = {
      keymap = {
        preset = 'enter',
        ['<Tab>'] = false,
        ['<S-Tab>'] = false,
      },
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
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- 开启 Mason
      require("mason").setup()

      local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
      local root_files = {
        "tsconfig.json",
        "jsconfig.json",
        "package.json",
        "pnpm-workspace.yaml",
        ".git",
      }
      local vue_language_server_path = vim.fn.stdpath("data")
        .. "/mason/packages/vue-language-server/node_modules/@vue/language-server"
      local vue_plugin = {
        name = "@vue/typescript-plugin",
        location = vue_language_server_path,
        languages = { "vue" },
        configNamespace = "typescript",
      }

      -- 配置需要自动安装的服务端（根据你的 JS/TS 需求）
      local servers = {
        vtsls = {
          cmd = { mason_bin .. "/vtsls", "--stdio" },
          capabilities = capabilities,
          settings = {
            vtsls = {
              tsserver = {
                globalPlugins = {
                  vue_plugin,
                },
              },
            },
          },
          filetypes = {
            "javascript",
            "javascriptreact",
            "typescript",
            "typescriptreact",
            "vue",
          },
          root_markers = root_files,
          single_file_support = true,
        }, -- TypeScript/JavaScript，并支持 .vue 中的 TS
        vue_ls = {
          cmd = { mason_bin .. "/vue-language-server", "--stdio" },
          capabilities = capabilities,
          root_markers = root_files,
          single_file_support = true,
        }, -- Vue 3 模板/CSS/HTML 支持
        lua_ls = {
          capabilities = capabilities,
        }, -- Lua 支持
        html = {},
        cssls = {},
        somesass_ls = {},
      }

      for server_name, server in pairs(servers) do
        server.capabilities = server.capabilities or capabilities
        servers[server_name] = server
      end

      for server_name, server in pairs(servers) do
        vim.lsp.config(server_name, server)
      end

      require("mason-lspconfig").setup({
        ensure_installed = vim.tbl_keys(servers),
        automatic_enable = false,
      })

      vim.lsp.enable(vim.tbl_keys(servers))

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
