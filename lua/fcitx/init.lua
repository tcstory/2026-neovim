local M = {}

function M.setup()
  if vim.fn.executable("fcitx5-remote") ~= 1 then
    return
  end

  local has_busctl = vim.fn.executable("busctl") == 1

  --- 查询当前 Rime 是否处于 ASCII (英文) 模式
  local function is_rime_ascii()
    if not has_busctl then
      return nil
    end
    local res = vim.system(
      { "busctl", "--user", "call", "org.fcitx.Fcitx5", "/rime", "org.fcitx.Fcitx.Rime1", "IsAsciiMode" },
      { text = true }
    ):wait()
    if res.code == 0 and res.stdout then
      return res.stdout:match("b%s+(%a+)") == "true"
    end
    return nil
  end

  --- 设置 Rime 的 ascii_mode (true 为英文模式，false 为中文模式)
  local function set_rime_ascii(ascii)
    if has_busctl then
      vim.system({
        "busctl",
        "--user",
        "call",
        "org.fcitx.Fcitx5",
        "/rime",
        "org.fcitx.Fcitx.Rime1",
        "SetAsciiMode",
        "b",
        ascii and "true" or "false",
      })
    end
  end

  --- 确保当前输入法处于 rime
  local function ensure_rime()
    local res = vim.system({ "fcitx5-remote", "-n" }, { text = true }):wait()
    if res.code == 0 and res.stdout and vim.trim(res.stdout) ~= "rime" then
      vim.system({ "fcitx5-remote", "-s", "rime" }):wait()
    end
  end

  local group = vim.api.nvim_create_augroup("Fcitx5RimeNativeSwitch", { clear = true })

  -- 离开插入模式：若刚才在打中文，记录并在 Rime 内部切为英文模式 (ascii_mode = true)
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function()
      local ascii = is_rime_ascii()
      if ascii == false then
        vim.b.saved_rime_chinese = true
        set_rime_ascii(true)
      elseif ascii == true then
        vim.b.saved_rime_chinese = false
      end
    end,
  })

  -- 进入插入模式：若离开前是中文状态，自动恢复为中文 (ascii_mode = false)
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function()
      if vim.b.saved_rime_chinese == true then
        set_rime_ascii(false)
      end
    end,
  })

  -- 退出命令行（搜索、命令）：确保回到 Normal 模式时为英文模式
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      set_rime_ascii(true)
    end,
  })

  -- 窗口重新获得焦点：确保处于 Rime 且为英文模式
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      local m = vim.fn.mode()
      if m == "n" or m:match("^[vV\022sS]") then
        ensure_rime()
        set_rime_ascii(true)
      end
    end,
  })

  -- 初始化：确保当前是 Rime 且处于英文模式
  local m = vim.fn.mode()
  if m == "n" or m:match("^[vV\022sS]") then
    ensure_rime()
    set_rime_ascii(true)
  end
end

return M
