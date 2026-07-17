if not vim.g.neovide then
  return
end

-- 英文字体在前，中文字体在后。
vim.opt.guifont = "BlexMono Nerd Font Mono,LXGW WenKai:h12"

-- 霞鹜文楷字形偏大，需要时可以增加行间距。
-- vim.opt.linespace = 2

vim.g.neovide_font_hinting = "full"

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


