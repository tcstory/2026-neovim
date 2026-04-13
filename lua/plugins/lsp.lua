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
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      capabilities.textDocument.completion.completionItem.snippetSupport = true
      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      }
      local vue2_target_warned = {}

      -- 开启 Mason
      require("mason").setup()

      local node_bin = "/home/tcstory/.nvm/versions/node/v24.13.0/bin/node"
      local root_files = {
        "tsconfig.json",
        "jsconfig.json",
        "package.json",
        "vue.config.js",
        "vue.config.ts",
      }
      local workspace_root_files = {
        "pnpm-workspace.yaml",
        ".git",
      }
      local vue_language_server_path = vim.fn.stdpath("data")
        .. "/mason/packages/vue-language-server/node_modules/@vue/language-server"
      local vtsls_main = vim.fn.stdpath("data")
        .. "/mason/packages/vtsls/node_modules/@vtsls/language-server/dist/main.js"
      local vue_ls_main = vue_language_server_path .. "/index.js"
      local vue_plugin = {
        name = "@vue/typescript-plugin",
        location = vue_language_server_path,
        languages = { "vue" },
        configNamespace = "typescript",
      }

      local function find_upward(bufnr, names)
        local path = vim.api.nvim_buf_get_name(bufnr)
        if path == "" then
          return nil
        end
        return vim.fs.find(names, {
          path = vim.fs.dirname(path),
          upward = true,
        })[1]
      end

      local function read_file(path)
        local ok, lines = pcall(vim.fn.readfile, path)
        if not ok then
          return nil
        end
        return table.concat(lines, "\n")
      end

      local function maybe_warn_vue2_target(bufnr)
        if vim.bo[bufnr].filetype ~= "vue" then
          return
        end

        local package_json = find_upward(bufnr, { "package.json" })
        if not package_json then
          return
        end

        local root = vim.fs.dirname(package_json)
        if vue2_target_warned[root] then
          return
        end

        local package_content = read_file(package_json)
        if not package_content then
          return
        end

        local ok, package = pcall(vim.json.decode, package_content)
        if not ok or type(package) ~= "table" then
          return
        end

        local vue_version = (package.dependencies or {}).vue
          or (package.devDependencies or {}).vue
          or (package.peerDependencies or {}).vue
        if type(vue_version) ~= "string" or not vue_version:match("^%D*2[.%d]*") then
          return
        end

        local config_path = find_upward(bufnr, { "tsconfig.json", "jsconfig.json" })
        if not config_path then
          vue2_target_warned[root] = true
          vim.notify(
            "检测到 Vue 2 项目，建议在 tsconfig.json 或 jsconfig.json 中显式设置 vueCompilerOptions.target = 2.7。",
            vim.log.levels.WARN
          )
          return
        end

        local config_content = read_file(config_path)
        if not config_content then
          return
        end

        local has_vue_target = config_content:match('"vueCompilerOptions"%s*:%s*{[^}]-"target"%s*:%s*[\'"]?2')
          or config_content:match("'vueCompilerOptions'%s*:%s*{[^}]-'target'%s*:%s*[\'\"]?2")
        if has_vue_target then
          return
        end

        vue2_target_warned[root] = true
        vim.notify(
          "检测到 Vue 2 项目，但当前未显式设置 vueCompilerOptions.target。建议在 "
            .. vim.fs.basename(config_path)
            .. " 中加入 vueCompilerOptions = { target = 2.7 }。",
          vim.log.levels.WARN
        )
      end

      local function nearest_project_root(bufnr, on_dir)
        local root = vim.fs.root(bufnr, root_files)
        if root then
          on_dir(root)
          return
        end

        local workspace_root = vim.fs.root(bufnr, workspace_root_files)
        if workspace_root then
          on_dir(workspace_root)
        end
      end

      -- 配置需要自动安装的服务端（根据你的 JS/TS 需求）
      local servers = {
        vtsls = {
          cmd = { node_bin, vtsls_main, "--stdio" },
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
          root_dir = nearest_project_root,
          root_markers = root_files,
          single_file_support = true,
        }, -- TypeScript/JavaScript，并支持 .vue 中的 TS
        vue_ls = {
          cmd = { node_bin, vue_ls_main, "--stdio" },
          capabilities = capabilities,
          -- Vue language tools 会优先从项目的 tsconfig/jsconfig 读取
          -- vueCompilerOptions.target；未显式配置时默认自动探测项目中的 Vue 版本。
          root_dir = nearest_project_root,
          root_markers = root_files,
          single_file_support = true,
        }, -- Vue 2/3 模板/CSS/HTML 支持，版本由项目配置决定
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

      vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
        pattern = "*.vue",
        callback = function(args)
          maybe_warn_vue2_target(args.buf)
        end,
      })

      -- 自定义 LSP 快捷键（结合你的 Snacks.picker 提升体验）
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          local function bufopts(desc)
            return { buffer = args.buf, desc = desc }
          end

          -- 使用 Snacks 替代原生的跳转，界面更漂亮
          vim.keymap.set("n", "gd", function() Snacks.picker.lsp_definitions() end, bufopts("Definitions"))
          vim.keymap.set("n", "gr", function() Snacks.picker.lsp_references() end, bufopts("References"))
          vim.keymap.set("n", "gi", function() Snacks.picker.lsp_implementations() end, bufopts("Implementations"))
          vim.keymap.set("n", "gt", function() Snacks.picker.lsp_type_definitions() end, bufopts("Type Definitions"))

          -- 代码操作和重命名
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, bufopts("Code Action"))
          vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, bufopts("Rename"))

          -- 悬浮文档
          vim.keymap.set("n", "K", vim.lsp.buf.hover, bufopts("Hover"))
        end,
      })
    end,
  },
}
