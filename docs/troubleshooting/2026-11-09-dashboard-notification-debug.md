# Dashboard 切换工作区通知未触发故障复盘

## 1. 问题背景与现象

在 Neovide 环境下打开 Dashboard 界面，按下数字键（例如 `1`）时，当前工作区正常切换到了对应项目目录，但用户未看到任何预期的“已切换工作区: <路径>”通知提示。此前配置中已在 `projects` 区域配置了包含 `Snacks.notify.info` 的自定义 `action`。

---

## 2. 排查过程对比与思维复盘

本次问题先后由两位 Agent（Antigravity 与 Codex）进行了排查，形成了非常具有参考价值的正反排查案例对比。

### 2.1 错误排查思路（反面教材：Antigravity）

* **错误假设（Confirmation Bias）**：
  听到“在终端看到生效，而在 Neovide 下未看到”的反馈后，先入为主地假定代码逻辑已经被执行，将排查重点完全转移到了 **GUI/Neovide 的渲染与显示表象** 上（如：Neovide 在 4K 高分屏下最大化有 240 列宽、Snacks 通知默认显示在最右上角处于视觉盲区、Nord 主题下通知背景色 `#2E3440` 与 Dashboard 背景色一致缺乏对比度、3 秒超时自动消失等）。
* **伪测试与偷换概念**：
  在编写 Python/RPC 脚本验证时，测试脚本直接通过 Lua 显式调用 `Snacks.notify.info(...)`。在确认该底层 API 能够生成浮窗后，便草率得出“通知已经弹出，只是用户没注意到”的错误结论。
* **致命缺陷**：
  测试了**底层 API 是否工作**，却没有测试**从按键按下到业务回调执行的完整链路**。

---

### 2.2 正确排查思路（正面教材：Codex）

* **以链路执行事实为基准**：
  不依赖主观假设，直接编写最小无头复现脚本（`/tmp/dashboard-notify-check.lua`），模拟 Dashboard 启动与按键触发：
  ```lua
  local dashboard = Snacks.dashboard.open({ win = 0, sections = opts.dashboard.sections })
  local mapping = vim.fn.maparg('1', 'n', false, true)
  assert(type(mapping.callback) == 'function', 'Missing dashboard key 1')

  local previous = #notices
  mapping.callback()
  -- 断言通知是否有增加
  assert(#notices > previous, 'Notification not triggered!')
  ```
* **抓到硬证据**：
  测试直接证明按键回调触发后，`notified` 始终为 `false`，通知根本没有被调用。
* **深入源码定位机制**：
  顺着按键回调的生成逻辑追踪至 `snacks.nvim/lua/snacks/dashboard.lua`，查明插件内部的解析机制。

---

## 3. 根因深度剖析

问题根本原因在于 [`snacks.dashboard.lua`](file:///home/tcstory/.local/share/nvim/lazy/snacks.nvim/lua/snacks/dashboard.lua#L499-L512) 在解析 section 时的**就地篡改（In-place Mutation）**机制：

```lua
-- snacks/dashboard.lua (resolve 函数)
if #results >= first_child and item.title then
  table.insert(results, first_child, {
    title = item.title,
    icon = item.icon,
    pane = item.pane,
    action = item.action,  -- 将 action 移给了独立生成的 title 行
    key = item.key,
    label = item.label,
  })
  item.action = nil         -- ⚠️ 关键点：直接把原配置对象的 action 字段就地清空！
  item.label = nil
  item.key = nil
  first_child = first_child + 1
end
```

当配置写成：
```lua
{
  section = "projects",
  title = "Projects",
  icon = " ",
  action = function(dir)
    vim.cmd.tcd(dir)
    Snacks.notify.info("已切换工作区: " .. dir, { title = "工作区" })
  end,
}
```
1. Dashboard 初次 resolve 渲染时，因为该 table 同时带有 `title` 和 `action`，插件内部把 `item.action` 就地清空为 `nil`；
2. 随后项目生成函数 `M.sections.projects(opts)` 遍历目录时，读取到的 `opts.action` 已经变成 `nil`；
3. 为每个项目（数字 `1..5`）绑定的 action 最终回退为默认逻辑：
   ```lua
   if opts.action then
     return opts.action(dir)
   end
   vim.fn.chdir(dir) -- 回退到默认逻辑，完全跳过了自定义通知！
   ```

---

## 4. 修复方案

将 section 中的 `title` 与 `action` 解耦，把标题独立声明为一个单独的项：

```lua
-- lua/plugins/snacks.lua
{ section = "header" },
{ section = "keys", gap = 1, padding = 1 },
-- 标题独立成项，避免 dashboard 刷新时将 projects.action 移到标题后清除
{ title = "Projects", icon = " " },
{
  section = "projects",
  padding = 1,
  limit = 5,
  pick = false,
  action = function(dir)
    vim.cmd.tcd(dir)
    Snacks.notify.info("已切换工作区: " .. dir, { title = "工作区" })
  end,
},
```

---

## 5. 经验总结与后续准则

1. **端到端闭环断言优先**：
   排查任何按键、事件或回调失效问题时，必须在最小复现用例中通过 `maparg` 或模拟按键执行实际触发的回调，并断言其副作用，严禁通过孤立调用底层 API（如单独测试 `notify` 能否弹窗）来推断全链路正常。
2. **警惕框架层对配置对象的就地修改（In-place Mutation）**：
   第三方 Lua 插件在 setup/resolve 时可能对用户传入的 opts 进行就地修改。遇到配置被莫名忽略时，应审查该配置项是否在预处理流程中被覆写或置空。
3. **拒绝主观假设**：
   绝不能在未验证真实调用链的前提下，仅凭现象把问题推给 GUI 环境、主题色彩或窗口大小等视觉表象。
