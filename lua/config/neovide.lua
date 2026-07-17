if not vim.g.neovide then
  return
end

-- 优先使用霞鹜文楷等宽，Nerd Font 用于图标和缺失字形回退。
vim.opt.guifont = "LXGW WenKai Mono,BlexMono Nerd Font Mono:h12"

-- 霞鹜文楷字形偏大，需要时可以增加行间距。
-- vim.opt.linespace = 2

vim.g.neovide_font_hinting = "full"

-- 保留 Dragon 的深色质感，只让背景轻微透出桌面。
vim.g.neovide_opacity = 0.96
vim.g.neovide_normal_opacity = 0.96

-- 浮窗使用轻度模糊、圆角和阴影，增强与编辑区的层次感。
vim.g.neovide_floating_blur_amount_x = 2.0
vim.g.neovide_floating_blur_amount_y = 2.0
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

-- 为浮窗模糊提供少量透明度；补全菜单略微更实，保证文字清晰。
vim.opt.winblend = 10
vim.opt.pumblend = 6

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
