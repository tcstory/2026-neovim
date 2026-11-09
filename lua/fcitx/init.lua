local M = {}

function M.setup()
  if vim.fn.executable("fcitx5-remote") ~= 1 or vim.fn.executable("busctl") ~= 1 then
    return
  end
  if M.configured then
    return
  end
  M.configured = true

  local queue, running = {}, false
  local stopping = false
  local process
  local bus = { "busctl", "--user", "call", "org.fcitx.Fcitx5", "/rime", "org.fcitx.Fcitx.Rime1" }
  local function call(args, callback)
    if stopping then
      return
    end
    local ok = pcall(function()
      process = vim.system(args, { text = true, timeout = 250 }, function(result)
        vim.schedule(function()
          process = nil
          if not stopping then
            callback(result)
          end
        end)
      end)
    end)
    if not ok then
      callback({ code = -1 })
    end
  end
  local function rime(method, extra, callback)
    local args = vim.list_extend(vim.deepcopy(bus), { method })
    vim.list_extend(args, extra or {})
    call(args, callback)
  end
  local function set_ascii(ascii, done)
    rime("SetAsciiMode", { "b", ascii and "true" or "false" }, done)
  end
  local function pump()
    if running or stopping or #queue == 0 then
      return
    end
    running = true
    local task = table.remove(queue, 1)
    task(function()
      running = false
      pump()
    end)
  end
  local function enqueue(task)
    queue[#queue + 1] = task
    pump()
  end
  local function leave(buf)
    enqueue(function(done)
      rime("IsAsciiMode", nil, function(result)
        if result.code == 0 and vim.api.nvim_buf_is_valid(buf) then
          local value = (result.stdout or ""):match("b%s+(%a+)")
          if value == "true" or value == "false" then
            vim.b[buf].saved_rime_chinese = value == "false"
          end
        end
        set_ascii(true, done)
      end)
    end)
  end
  local function enter(buf)
    enqueue(function(done)
      if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].saved_rime_chinese then
        set_ascii(false, done)
      else
        done()
      end
    end)
  end
  local function english(ensure)
    enqueue(function(done)
      if not ensure then
        return set_ascii(true, done)
      end
      call({ "fcitx5-remote", "-n" }, function(result)
        if result.code == 0 and vim.trim(result.stdout or "") ~= "rime" then
          call({ "fcitx5-remote", "-s", "rime" }, function()
            set_ascii(true, done)
          end)
        else
          set_ascii(true, done)
        end
      end)
    end)
  end
  local group = vim.api.nvim_create_augroup("Fcitx5RimeNativeSwitch", { clear = true })
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = group,
    callback = function(ev)
      leave(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    callback = function(ev)
      enter(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = group,
    pattern = { "t:*", "*:t" },
    callback = function(ev)
      if vim.bo[ev.buf].buftype ~= "terminal" then
        return
      end
      if ev.match:match(":t$") then
        enter(ev.buf)
      else
        leave(ev.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("CmdlineLeave", {
    group = group,
    callback = function()
      english(false)
    end,
  })
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      if vim.fn.mode():match("^[nvVsS\022]") then
        english(true)
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      stopping, queue = true, {}
      if process then
        process:kill(15)
      end
    end,
  })
  if vim.fn.mode():match("^[nvVsS\022]") then
    english(true)
  end
end

return M
