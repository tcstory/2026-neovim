return {
  "lukas-reineke/headlines.nvim",
  ft = { "org" },
  dependencies = { "nvim-orgmode/orgmode" },
  config = function()
    local function highlights()
      -- 淡背景保留 Org 原有的标题与任务状态文字颜色。
      vim.api.nvim_set_hl(0, "OrgHeadlineBackground", { bg = "#343C4B" })
      vim.api.nvim_set_hl(0, "OrgCodeBackground", { bg = "#292E39" })
    end
    highlights()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("org_headline_colors", { clear = true }),
      callback = highlights,
    })
    require("headlines").setup({
      -- Markdown 交由 render-markdown 处理。
      markdown = { query = false },
      rmd = { query = false },
      norg = { query = false },
      org = {
        headline_highlights = { "OrgHeadlineBackground" },
        codeblock_highlight = "OrgCodeBackground",
        bullets = {},
        fat_headlines = false,
      },
    })
    -- 首次打开即渲染；切换窗口或文件时同步刷新。
    vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "WinEnter" }, {
      group = vim.api.nvim_create_augroup("org_headline_refresh", { clear = true }),
      callback = function()
        if vim.bo.filetype == "org" then
          require("headlines").refresh()
        end
      end,
    })
    if vim.bo.filetype == "org" then
      require("headlines").refresh()
    end
  end,
}
