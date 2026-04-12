return {
  "kevinhwang91/nvim-ufo",
  dependencies = "kevinhwang91/promise-async",
  event = "BufReadPost", -- 延迟加载，提高启动速度
  opts = {
    -- Vue SFC 需要手动处理 provider 回退：
    -- LSP 常见情况是“返回空 folds”而不是抛 fallback 异常。
    provider_selector = function(bufnr, filetype, buftype)
      if filetype == "vue" then
        return function(bufnr)
          local ufo = require("ufo")
          return ufo.getFolds(bufnr, "lsp"):thenCall(function(ranges)
            if ranges and not vim.tbl_isempty(ranges) then
              return ranges
            end
            return ufo.getFolds(bufnr, "treesitter")
          end, function()
            return ufo.getFolds(bufnr, "treesitter")
          end)
        end
      end
      return { "lsp", "indent" }
    end,
  },
  config = function(_, opts)
    -- nvim-ufo 需要设置一些全局参数
    vim.o.foldmethod = "manual"
    vim.o.foldlevel = 99 -- 默认展开所有折叠
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true

    require("ufo").setup(opts)
    
    -- 快捷键设置：zR 展开所有，zM 关闭所有
    vim.keymap.set("n", "zR", require("ufo").openAllFolds)
    vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
  end,
}
