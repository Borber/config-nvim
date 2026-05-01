# config-nvim

个人 Neovim 配置，使用 `lazy.nvim` 管理插件。当前配置偏向项目工作流：启动页负责项目入口和最近路径，`mini.files` 负责文件树，`mini.sessions` 负责项目会话，Telescope / Trouble / Overseer 分别承担查找、诊断列表和任务运行。

## 依赖

- Neovim 0.12+
- `git`
- Windows 下使用 bookmarks 时建议通过 Scoop 安装 `sqlite-dll`，配置会自动使用 `~/scoop/apps/sqlite-dll/current/sqlite3.dll`
- `tree-sitter`：`nvim-treesitter` 使用 `main` 分支，需要本机有 `tree-sitter` 命令
- 可选：`rg`、`fd`、`cmake`，用于 Telescope / fzf-native 等插件获得更好体验
- 可选：`just`、`bun`、`npm`、`cargo` 等项目命令，用于 Overseer 自动发现并运行任务

## 本地私密配置

私密配置放在 `lua/config/local.lua`，该文件已加入 `.gitignore`，不会被 Git 同步。

第一次使用时复制示例文件：

```sh
cp lua\config\local.example.lua lua\config\local.lua
```

然后在 `lua/config/local.lua` 里填写本机配置，例如 LSP 诊断静音路径和 Codestral API key：

```lua
return {
  lsp = {
    diagnostic_mute_roots = {
      -- "/path/to/large/project",
    },
  },

  aicommits = {
    api_key = "your-codestral-api-key",
    endpoint = "https://codestral.mistral.ai/v1/chat/completions",
    model = "codestral-latest",
  },
}
```

不要把真实 key 或机器私有路径写进 `local.example.lua`。

LSP 诊断也可以通过项目内标记文件静音：在项目根或子目录放置 `.nvim-disable-lsp-diagnostics` 或 `.nvim/lsp-diagnostics-off`。这只会静音诊断，跳转、补全、hover 等 LSP 能力仍然保留。

## 常用入口

- `<leader>e`：打开 `mini.files` 文件树。
- `<leader>,`：打开 buffer picker；`<leader>/` 搜索当前 buffer，`<leader>ff` 查找文件，`<leader>fg` 全局搜索。
- `<leader>x` / `<leader>X`：删除当前 buffer / 强制删除当前 buffer。
- `<leader>ss` / `<leader>sr` / `<leader>sR` / `<leader>sd`：保存、恢复、选择、删除项目 session。
- `<leader>mm` / `<leader>mo` / `<leader>mt` / `<leader>ma`：当前项目的书签标记、跳转、树视图和动作菜单。
- `<leader>jr` / `<leader>jo` / `<leader>jf` / `<leader>js`：运行任务、切换任务列表、打开最近失败任务输出、运行临时 shell task。
- `<leader>gg` / `<leader>gc` / `<leader>gl`：Neogit status、commit、log。
- `<leader>fd` / `<leader>fD`：当前文件 / 工作区诊断列表；`]d` / `[d` 跳到下一条 / 上一条诊断并显示浮窗。

## 项目启动与会话

- 启动页展示内置入口、项目入口和最近路径；最近路径由 `lua/plugins/mini/visits.lua` 维护。
- 打开目录时会先切换 cwd，再尝试恢复当前项目 session；没有 session 时打开 `mini.files`。
- home 目录作为 starter 入口页，不写入项目 session。
- starter 的 `Open` 入口会临时启用 `mini.files` 中的 `<S-CR>`：只有最终确认打开的路径会写入最近路径，中间浏览目录不会污染记录。
- session 写入前会过滤无意义 buffer，空 session 会被清理，避免下次恢复到空壳布局。

## 加载与保存约定

- `ConfigFilePost` 会在 UI 已进入且首个真实文件 buffer 出现后触发，用于延后加载 gitsigns、todo-comments 等文件型插件。
- 自动保存只作用于正常、可写、有文件名且已修改的文件 buffer；terminal、help、quickfix、无名 buffer 和只读 buffer 不会被强行写盘。
- 读取和写入文件时会清理残留 `\r`，降低混合换行导致的 `^M` 噪音。

## Bookmarks

书签按当前 cwd 自动切换到同名项目列表，避免不同项目混用同一个 bookmarks 列表。树视图固定宽度为 50，并隐藏 number、signcolumn、foldcolumn 等额外栏位；目录折叠图标和书签图标会统一替换成更紧凑的样式。

## AI Commit

AI commit 使用 `404pilo/aicommits.nvim`，通过 OpenAI-compatible Chat Completions 接口连接 Codestral。

使用方式：

1. 在 Neogit 中 stage 需要提交的内容。
2. 按 `c` 打开 Neogit commit popup。
3. 在 `AI` 分组里按 `C` 执行 `AI Commit`。
4. 从生成结果中选择 commit message。

说明：

- `aicommits.nvim` 的 Neogit integration 已开启，用于提交后刷新 Neogit。
- 插件自带的 Neogit status 页独立 `C` 映射已关闭。
- AI action 由 `lua/plugins/neogit.lua` 注入到 Neogit commit popup。
- 默认生成 5 条候选 commit message。

## Neogit 仓库识别

`:Neogit` 和 `<leader>gg` / `<leader>gc` / `<leader>gl` 会优先从当前 buffer 的文件目录执行 `git rev-parse --show-toplevel`，再回退到当前 cwd。
需要手动指定仓库时，仍然可以使用 Neogit 原生参数，例如 `:Neogit cwd=/path/to/repo`。

## Overseer 任务

`<leader>jr` 会从当前文件目录开始搜索 Overseer 模板；当前 buffer 不是普通文件时回退到 cwd。任务模板和 action 选择使用 Telescope picker，仍保留 Overseer 自动发现的所有 providers。

任务启动时不会默认展开底部输出；失败后会自动打开输出窗口，或者用 `<leader>jf` 随时打开最近失败任务的输出。

## 界面约定

- 所有浮窗尽量复用 `lua/util/float.lua` 的单线边框和高亮约定，Telescope、Noice、LSP hover、diagnostic float、which-key、Overseer 等入口保持统一。
- lualine statusline 使用紧凑模式标签，例如 `N`、`I`、`V`、`T`；branch、diagnostics 和 filetype 会按窗口宽度条件显示，最右侧显示当前 OS 图标。
- 顶部 tabline 左侧保留独立 Vim 图标区，buffer 列表只显示简洁名称，并用 `●` 标记已修改 buffer。
- gitsigns 在 signcolumn 中显示新增/变更线，也用 `` 明确标记删除和顶部删除。
- signcolumn 默认保留，避免诊断、git sign 或书签 sign 出现时正文左右跳动。
- Markdown 链接相关快捷键放在 `after/ftplugin/markdown.lua`，Lua 文件局部设置放在 `after/ftplugin/lua.lua`。

## Headless 验证

关键交互边界可以用 Neovim headless 脚本验证：

```sh
nvim --headless -u NONE -i NONE -n -S tests/headless/mini_behaviors.lua +qa
```
