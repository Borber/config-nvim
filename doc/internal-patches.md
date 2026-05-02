# 内部 Patch 维护记录

本文件记录配置里主动改写插件内部入口或全局入口的地方。升级相关插件后，优先按这里的“最小回归”检查，而不是只看是否能启动。

## blink.cmp accept preview

- 文件：`lua/plugins/blink.lua`
- 目标入口：`package.loaded["blink.cmp.completion.accept.preview"]`
- 目的：替换 blink 内部的补全预览逻辑，让 Copilot/LSP 多行候选能临时展开并在候选变化或菜单关闭时撤销。
- 风险：blink 内部模块路径、`text_edits` API 或 snippet 展开 API 变化后，预览可能失效或撤销不完整。
- 最小回归：插入模式触发多行 Copilot/LSP 候选，移动候选后原文应恢复；接受候选后文本应只插入一次。

## noice signature guard

- 文件：`lua/plugins/noice.lua`
- 目标入口：`noice.lsp.signature.check`、`noice.lsp.signature.on_signature`
- 目的：当 blink 补全菜单可见时压住 Noice signature popup，避免两个浮窗抢同一块视线。
- 风险：Noice signature 模块改名或函数签名变化后，签名帮助可能不再被抑制。
- 最小回归：函数调用位置同时触发补全和签名帮助时，补全菜单优先；补全菜单关闭后签名帮助仍可正常出现。

## bookmarks tree render

- 文件：`lua/plugins/bookmarks.lua`
- 目标入口：`bookmarks.tree.render.refresh`
- 目的：在上游 tree 渲染后替换展开/折叠图标，并保持 tree 窗口宽度和 gutter 统一。
- 风险：bookmarks.nvim 内部 tree 模块路径、渲染函数或 `vim.g.bookmark_tree_view_ctx` 结构变化后，图标替换或宽度修正可能失效。
- 最小回归：执行 `:BookmarksProjectTree`，展开/折叠图标应是配置图标；窗口 resize 后 tree 宽度应回到配置值。

## Neogit commit popup action

- 文件：`lua/plugins/neogit.lua`
- 目标入口：`opts.builders.NeogitCommitPopup`
- 目的：把 AI commit action 放在 Neogit commit popup 内部，保持 Neogit status 页和 commit popup 的职责边界。
- 风险：Neogit popup builder API 或 popup 名称变化后，`C` action 可能不再出现。
- 最小回归：打开 Neogit commit popup，AI 分组内应有 `C` / `AI Commit`，并调用 `aicommits.commit()`。

## Overseer vim.ui.select route

- 文件：`lua/plugins/overseer.lua`
- 目标入口：`vim.ui.select`
- 目的：只把 `kind=overseer*` 的模板/action 选择路由到 Telescope picker，其它调用继续走原始 `vim.ui.select`。
- 风险：Overseer 改变 `kind` 命名后，模板或 action 选择可能回退到默认 UI。
- 最小回归：`<leader>jr` 运行任务时应打开 Telescope 风格选择器；非 Overseer 的 `vim.ui.select` 不应被这个路由影响。

## toggleterm open_split

- 文件：`lua/plugins/toggleterm.lua`
- 目标入口：`toggleterm.ui.open_split`
- 目的：创建或打开终端时临时替换 split 创建逻辑，让 horizontal 终端共享底部横条，vertical 终端共享右侧竖条，且互不破坏已有窗口布局。
- 风险：toggleterm 内部 `ui.open_split`、`ui.resize_split`、`Terminal` buffer 初始化流程变化后，终端窗口可能打开到错误区域。
- 最小回归：连续打开多个 horizontal / vertical 终端；horizontal 应在底部横向分列，vertical 应在右侧纵向分行，已有终端 buffer 内容和滚动位置不应被重建。
