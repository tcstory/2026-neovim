if not vim.g.neovide then
  return
end

-- 优先使用霞鹜文楷等宽，Nerd Font 用于图标和缺失字形回退。
vim.opt.guifont = "LXGW WenKai Mono,BlexMono Nerd Font Mono:h12"

-- 霞鹜文楷字形偏大，需要时可以增加行间距。
-- vim.opt.linespace = 2

vim.g.neovide_font_hinting = "full"

-- 纯色背景，关闭透明度与桌面透出（与终端版本保持一致）
vim.g.neovide_opacity = 1.0
vim.g.neovide_normal_opacity = 1.0

-- 浮窗关闭背景模糊与半透，保留阴影与圆角层次感
vim.g.neovide_floating_blur_amount_x = 0.0
vim.g.neovide_floating_blur_amount_y = 0.0
vim.g.neovide_floating_shadow = true
vim.g.neovide_floating_z_height = 10
vim.g.neovide_light_angle_degrees = 45
vim.g.neovide_light_radius = 5
vim.g.neovide_floating_corner_radius = 0.35

-- 动画保持短促，既能看清位置变化，又不会拖慢操作感。
vim.g.neovide_cursor_animation_length = 0.08
vim.g.neovide_cursor_trail_size = 0.4
vim.g.neovide_cursor_antialiasing = true
vim.g.neovide_cursor_animate_in_insert_mode = true
vim.g.neovide_scroll_animation_length = 0.15
vim.g.neovide_scroll_animation_far_lines = 1

-- 纯实色浮窗与补全菜单，文字扎实清晰
vim.opt.winblend = 0
vim.opt.pumblend = 0

local function paste_with_reindent()
  vim.cmd.normal({ '"+p', bang = true })
  local view = vim.fn.winsaveview()
  vim.cmd([[silent! normal! `[v`]=]])
  vim.fn.winrestview(view)
end

local function paste_to_terminal()
  local text = vim.fn.getreg("+")
  local job = vim.b.terminal_job_id

  if text == "" then
    return
  end

  if not job then
    vim.notify("Current buffer is not an active terminal", vim.log.levels.WARN)
    return
  end

  vim.api.nvim_chan_send(job, text)
end

vim.keymap.set({ "n", "v" }, "<C-S-c>", '"+y', { desc = "Copy to Clipboard" })
vim.keymap.set("i", "<C-S-v>", function()
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)
  vim.schedule(function()
    paste_with_reindent()
    vim.cmd.startinsert()
  end)
end, { desc = "Paste from Clipboard" })
vim.keymap.set("c", "<C-S-v>", "<C-r>+", { desc = "Paste from Clipboard" })
vim.keymap.set("n", "<C-S-v>", paste_with_reindent, { desc = "Paste from Clipboard" })
vim.keymap.set("v", "<C-S-v>", '"+p', { desc = "Paste from Clipboard" })
vim.keymap.set("t", "<C-S-v>", paste_to_terminal, { desc = "Paste from Clipboard" })

--------------------------------------------------------------------------------
-- 待办与能力跟踪 (TODO & Feature Tracking)
--------------------------------------------------------------------------------
-- [图片渲染限制与未来展望]
-- 现状：当前 Neovide（v0.16.x）基于独立 GUI 架构（Rust + Skia），与 Neovim 通过 RPC 通信，
-- 不解析终端转义序列，因此暂不支持 Kitty Graphics Protocol（无法像 Kitty 终端那样使用 image.nvim 行内渲染）。
-- 当前解决方案：Markdown/图表采用 `<leader>mp`（markdown-preview.nvim）在浏览器中高清实时预览。
-- 未来规划：当 Neovide 官方落地原生图像绘制 RPC/协议支持（跟踪 Issue #2088 / #2663）后，
-- 可在此处或插件配置中引入行内图片/文档图表渲染能力。

