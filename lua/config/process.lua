local M = {}

-- 保留 stdout 原始字节；路径调用方自行去除换行，文件内容不能 trim。
function M.run(cmd, cwd)
  local ok, result = pcall(function()
    return vim.system(cmd, { cwd = cwd, timeout = 5000 }):wait()
  end)
  if not ok then
    return nil, tostring(result)
  end
  if result.code ~= 0 then
    local err = vim.trim(result.stderr or "")
    return nil, err ~= "" and err or ("Command failed: " .. table.concat(cmd, " "))
  end
  return result.stdout or ""
end

return M
