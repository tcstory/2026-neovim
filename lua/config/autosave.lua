local launched_with_autosave = vim.env.TCSTORY_NVIM_AUTOSAVE == "1"
vim.env.TCSTORY_NVIM_AUTOSAVE = nil

local enabled = vim.g.neovide or launched_with_autosave
local api = vim.api
local M = { enabled = enabled }

function M.is_eligible(bufnr)
  bufnr = bufnr or 0
  return M.enabled
    and api.nvim_buf_is_valid(bufnr)
    and api.nvim_buf_is_loaded(bufnr)
    and vim.bo[bufnr].buftype == ""
    and vim.bo[bufnr].modifiable
    and not vim.bo[bufnr].readonly
    and api.nvim_buf_get_name(bufnr) ~= ""
end

if not enabled then
  return M
end

local function can_save(bufnr)
  return M.is_eligible(bufnr) and vim.bo[bufnr].modified
end

local function save_buffer(bufnr)
  if not can_save(bufnr) then
    return
  end

  local ok, err = pcall(api.nvim_buf_call, bufnr, function()
    vim.cmd("silent update")
  end)
  if not ok then
    vim.schedule(function()
      vim.notify(("Auto-save failed: %s"):format(err), vim.log.levels.ERROR)
    end)
  end
end

local group = api.nvim_create_augroup("tcstory_autosave", { clear = true })

api.nvim_create_autocmd("BufLeave", {
  group = group,
  callback = function(args)
    save_buffer(args.buf)
  end,
})

api.nvim_create_autocmd("FocusLost", {
  group = group,
  callback = function()
    for _, bufnr in ipairs(api.nvim_list_bufs()) do
      save_buffer(bufnr)
    end
  end,
})

return M
