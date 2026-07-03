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

## aicommits Neogit integration

- 文件：`lua/plugins/aicommits.lua`
- 目标入口：`aicommits.nvim` 的 Neogit integration 配置。
- 目的：把 AI commit 接入交给 aicommits 上游集成，避免继续维护本地 Neogit popup builder patch。
- 风险：aicommits 或 Neogit integration API 变化后，Neogit 内部入口可能不再出现或无法调用生成流程。
- 最小回归：`:AICommit`、`:AICommitHealth` 可用；从 Neogit 触发 AI commit 时能正常进入候选生成流程。

## Overseer vim.ui.select route

- 文件：`lua/plugins/overseer.lua`
- 目标入口：`vim.ui.select`
- 目的：只把 `kind=overseer*` 的模板/action 选择路由到 fzf-lua picker，其它调用继续走原始 `vim.ui.select`。
- 风险：Overseer 改变 `kind` 命名后，模板或 action 选择可能回退到默认 UI。
- 最小回归：`<leader>jr` 运行任务时应打开 fzf-lua 风格选择器；非 Overseer 的 `vim.ui.select` 不应被这个路由影响。
