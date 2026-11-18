# 生命周期与插件适配

## 生命周期

- `lua/config/lifecycle.lua` 的 UI 阶段直接使用 lazy.nvim 原生 `VeryLazy`；文件阶段使用一次性 `User ConfigFilePost`。
- `ConfigFilePost` 等待 `UIEnter`，只接受带本地文件路径的普通 buffer，跳过目录占位、URI、无名和特殊 buffer；尚未落盘的命名文件可以触发。
- `once(name, callback, opts)` 支持 `ui_ready` / `file_post`。晚订阅会回放已经发生的阶段，`opts.schedule` 对首次触发和晚回放都生效。
- `lazy_events` 提供插件规格使用的事件名；LSP、Gitsigns 等在首个真实文件就绪后加载。LSP 初始化使用原生 capabilities 和 Blink 的协商差异，Blink 自身在首次进入插入模式或命令行模式时加载。
- 状态局部保存在生命周期模块内；修改配置后重启 Neovim 生效。

## 项目入口

- `lua/config/project.lua` 统一 recent、session、home 策略，`lua/config/recent_projects.lua` 负责记录与打开项目。
- Starter `Open` 通过 `files.open(home, { confirm = true })` 临时启用 `<S-CR>`；普通 `open` / `toggle` 不启用确认键。
- 中间目录浏览不记录历史；最终确认统一走 `recent_projects.open_path`，取消关闭文件树时不记录也不切换项目。
- `Config` 入口继续使用 `{ record = false }` 和项目 session 恢复流程。

## Patch

- `lua/patches/bookmarks_tree.lua`
- `lua/patches/bookmarks_fzf_picker.lua`
- `lua/patches/overseer_select.lua`

Neogit 的 commit popup action 留在 `lua/plugins/neogit.lua`。Blink 候选预览使用上游默认行为，不再替换内部预览模块。各适配的风险和回归入口见 [维护记录](internal-patches.md)。

## 验证

```sh
nvim --headless -u NONE -i NONE -n -l tests/run.lua
```

运行前需安装配置依赖的插件。每个脚本在独立进程运行，保存清理测试使用真实 `mini.trailspace` 验证 Markdown 硬换行与普通代码清理。
