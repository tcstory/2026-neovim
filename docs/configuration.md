# 配置维护说明

## 保存与撤销历史

`config.autosave` 是唯一自动写回源文件的模块。启动时设置
`TCSTORY_NVIM_AUTOSAVE=1` 才启用，离开 buffer 或失去焦点时保存；保存会触发
`BufWritePre`、`BufWritePost`，并通过重入保护避免递归保存。

`config.history` 仅启用内置持久化撤销和历史选择器，继续使用
`stdpath("state")/local-history-undo` 中已有的历史。它没有保存定时器，也不自动清理历史。
`<leader>su` 和 `:LocalHistoryCheck` 打开撤销历史。

## 终端与工作区

`config.terminal` 管理整个 Neovim 会话的终端对象和唯一数字编号。
新终端使用当前标签页的工作目录；之后切换目录或标签页会复用原终端。
名称、关闭操作和窗口栏都关联同一对象，状态不再挂在全局变量上。

`config.terminal_links` 处理终端输出中的文件跳转，相对路径以终端启动目录为基准。
终端 shell 内自行执行 `cd` 后的目录不会同步回 Neovim。

## Git 与插件版本

`config.git` 负责 HEAD 对比和 Blame 提交定位。文件对比使用 Diffview，并复用原编辑
buffer，支持未保存改动；HEAD 快照保留原始空白，在对比标签页关闭后删除。
Blame 通过 Gitsigns 的文件 URI 匹配源 buffer，并将源仓库传给后续 Git 操作。

Diffview 从 `tcstory/diffview-plus.nvim` 安装，固定到原本本地副本的提交，不再要求
`~/Documents/Coding` 下存在源码。Node 从启动 Neovim 的 `PATH` 查找。

Neogit 的设置位于 `config.neogit`，涉及内部 API 的图谱及合并提交补丁集中在
`config.neogit_compat`。版本固定在该模块的 `commit` 字段；升级时同时更新锁文件并
运行回归测试，重点确认合并提交的首父差异和图谱显示。

## 输入法与菜单

`fcitx` 同时处理插入模式和终端模式的进入、退出。IPC 异步串行执行，每个命令限时
250ms，避免阻塞编辑器以及查询、设置互相超越。

`config.context_menu` 统一管理菜单的生命周期和操作，显示的快捷键对应实际映射。
文件名和终端名称在拼入 tabline / winbar 前转义 `%`。

## 回归测试

在仓库根目录运行（需要已经安装配置中的插件及 Node）：

```sh
XDG_STATE_HOME="$(mktemp -d)" nvim --headless -u NONE -i NONE -l tests/config_spec.lua
```

测试加载完整配置，使用临时 Git 仓库与真实插件，并执行真实映射回调或模拟按键、事件。
输入法 IPC 和终端重命名输入使用模拟后端，避免改变桌面输入法或等待交互；GUI 外观需在
Neovide 中检查。测试状态与撤销文件写入临时目录。

从旧版本迁移后应重启 Neovim / Neovide，使旧历史插件的定时器随旧进程退出。
