# AGENTS.md

本文件是这个 Neovim 配置仓库的项目级 agent 指令。修改本仓库时，优先遵守这里的约定；如果用户在当前对话里给出更具体的边界，以用户最新说明为准。

## 沟通

- 始终使用简体中文回复。
- 用户给出明确落地指令时，直接实现并验证，不要停留在泛泛方案。
- 解释影响范围时要说清楚哪些入口会变、哪些入口不会变。
- 做 review / 对比 / 差距分析时，优先给结论、风险和可吸收设计，不要只复述资料。

## 仓库定位

- 这是个人 Neovim 配置，使用 `lazy.nvim` 管理插件。
- 代码主要落在 `lua/config/`、`lua/plugins/`、`lua/plugins/mini/`、`lua/util/`、`after/ftplugin/` 和 `tests/headless/`。
- 配置偏向项目工作流：starter 负责入口，`mini.files` 负责文件树，`mini.visits` 负责最近路径和项目打开，`mini.sessions` 负责会话，Telescope / Trouble / Overseer 分别承担查找、诊断列表和任务运行。
- `lua/config/local.lua` 是本机私密配置，不能提交真实 key 或机器私有路径；示例只放在 `lua/config/local.example.lua`。

## 代码风格

- 优先复用现有模块、helper 和插件配置风格，不为局部问题引入全新抽象。
- Lua 文件保持小的 `local` helper，复杂逻辑放在靠近调用方的专用模块里。
- 公共路径、buffer、浮窗、Telescope picker 等能力优先复用 `lua/util/` 下已有 helper。
- 新注释只写在非显然交互边界或防御性逻辑前，保持简短。
- Lua 模块需要分区时，使用三行式中文分区标题：上下两行 `-- ============================================`，中间一行写短中文标题；分区按职责边界组织，例如配置读取、路径处理、窗口识别、布局调整、对外入口，不按单个函数流水账拆分。
- 分区下的正文注释说明行为边界、设计原因、平台差异或兜底策略；不要复述代码本身，也不要给显而易见的赋值、判断和函数调用加注释。
- 不要随手改无关插件、快捷键、主题或锁文件。
- 格式化遵循 `stylua.toml`；提交前尽量保持 diff 聚焦。

## 交互边界

- 先判断行为属于哪一层，再修改：
  - `mini.starter`：启动页、入口列表、前缀筛选、最近路径展示。
  - `mini.files`：文件树浏览、树内临时按键、目录分支展开。
  - `mini.visits`：最近路径记录、打开文件/目录、切换 cwd。
  - `mini.sessions`：项目 session 的保存、恢复、过滤和删除。
- starter 的特殊行为必须局部化，不能泄漏到普通 `mini.files` 使用。
- starter `Open` 里的 `<S-CR>` 是临时确认键；只有最终确认打开的路径才记录到 recent paths，中间浏览目录不能记录。
- 如果 starter 前缀筛选只剩一个候选，应直接执行，不要再要求回车。
- `Config` 这类表示目录/项目的入口要继续走 `visits.open_path(..., { record = false })` 和 session 恢复流程，不要改成单文件打开。
- home 目录作为 starter 入口页，不写入项目 session，也不要恢复 home session。
- session 写入只保留有意义的真实文件 buffer；空 session 应清理，避免下次恢复空壳布局。

## UI 与快捷键

- `lua/plugins/lualine.lua` 是 statusline/tabline 的主要落点；far-left Vim 图标应保持独立区块，buffer 列表放在后续 section。
- 浮窗边框、标题和高亮优先复用 `lua/util/float.lua`，让 Telescope、Noice、LSP、which-key、Overseer 等入口保持一致。
- `signcolumn` 默认保留，避免诊断、git sign 或书签 sign 出现时正文跳动。
- picker 体验优先使用 Telescope 风格；不要新增数字列表式 fallback，除非用户明确要求。
- `<leader>,` 是 buffer picker；不要把它和 `<leader>/` 当前 buffer 搜索、`<leader>ff` 文件查找混在一起。
- 一旦首选入口已经成立，应删除冗余备用入口，而不是保留多条相近路径。

## 任务、Git 与外部命令

- 不得自动执行 `git add`、`git commit`、`git push` 等会改变 Git 暂存区或远端状态的命令，除非用户明确要求。
- 不要污染用户已有暂存区：修改文件后保持为未暂存状态，让用户自己决定 stage 哪些内容。
- 查看 Git 状态时区分 staged、unstaged 和 untracked；汇报时要说明自己的改动落在哪一类。
- Overseer 任务入口应保留所有自动发现的 providers，不要静默缩窄到 `just` 或单一构建系统。
- Overseer 模板和 action 选择使用 Telescope picker；任务启动时不默认展开输出，失败后自动打开错误输出。
- Windows 下调试 `just` / shell 问题时，先查 PATH、PowerShell profile、Scoop shim 和子进程继承，不要先做应用层特判。
- Neogit 行为应和 Gitsigns / Diffview / aicommits 保持职责边界；AI commit 在 status 页保留直达 `C`，并在 commit popup 内提供同键的可发现入口。

## 验证

- 修改 starter、mini.files、mini.visits、mini.sessions 等交互边界后，优先运行：

```sh
nvim --headless -u NONE -i NONE -n -S tests/headless/mini_behaviors.lua +qa
```

- 需要最小语法/加载验证时，优先使用 headless Neovim，并加 `-i NONE` 避免 ShaDa 噪音。
- 修改 Markdown、Lua ftplugin 或工具模块时，至少检查对应文件可读、无明显格式错误。
- 做 README / AGENTS 文档变更时，运行 `git diff --check -- <file>`。
