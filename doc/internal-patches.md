# 内部 Patch 维护记录

本文件记录配置里主动改写插件内部入口或全局入口的地方。升级相关插件后，优先按这里的“最小回归”检查，而不是只看是否能启动。

## bookmarks tree render

- 文件：`lua/patches/bookmarks_tree.lua`（由 `lua/plugins/bookmarks.lua` 调用）
- 目标入口：`bookmarks.tree.render.refresh`
- 目的：在上游 tree 渲染后替换展开/折叠图标，并保持 tree 窗口宽度和 gutter 统一。
- 风险：bookmarks.nvim 内部 tree 模块路径、渲染函数或 `vim.g.bookmark_tree_view_ctx` 结构变化后，图标替换或宽度修正可能失效。
- 最小回归：执行 `:BookmarksProjectTree`，展开/折叠图标应是配置图标；窗口 resize 后 tree 宽度应回到配置值。

## bookmarks fzf-lua picker

- 文件：`lua/patches/bookmarks_fzf_picker.lua`（由 `lua/plugins/bookmarks.lua` 调用）
- 目标入口：`package.preload["bookmarks.picker"]`，在插件注册命令并缓存 picker 前设置。
- 目的：书签、列表和命令选择统一使用 fzf-lua，并为书签文件集合提供搜索入口。
- 风险：上游 picker 导出函数或 domain repo / node API 变化后，书签选择和命令执行可能失效。
- 最小回归：标记书签和打开书签树时保持 fzf-lua 延迟加载。跳转书签、切换列表、动作菜单与书签文件搜索都应打开 fzf-lua，取消选择不应执行动作。

## Neogit commit popup action

- 文件：`lua/plugins/neogit.lua`
- 目标入口：`opts.builders.NeogitCommitPopup`
- 目的：在 Neogit commit popup 内提供可发现的 AI commit action，同时保留 status 页的直达 `C`。
- 风险：Neogit popup builder API 或 popup 名称变化后，`C` action 可能不再出现。
- 最小回归：status 页的 `C` 可直接触发 AI Commit；打开 commit popup 后，AI 分组也应有 `C` / `AI Commit` 并调用 `aicommits.commit()`。

## Overseer vim.ui.select route

- 文件：`lua/patches/overseer_select.lua`（由 `lua/plugins/overseer.lua` 调用）
- 目标入口：`vim.ui.select`
- 目的：只把 `kind=overseer*` 的模板/action 选择路由到 fzf-lua picker，其它调用继续走原始 `vim.ui.select`。
- 风险：Overseer 改变 `kind` 命名后，模板或 action 选择可能回退到默认 UI。
- 最小回归：用 `<leader>jr` 在拥有多个任务模板的项目中打开 fzf-lua 选择器，并确认非 Overseer 的 `vim.ui.select` 仍使用原有入口。
