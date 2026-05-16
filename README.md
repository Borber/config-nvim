# config-nvim

个人 Neovim 配置，使用 `lazy.nvim` 管理插件。当前配置偏向项目工作流：启动页负责入口和最近路径，`mini.files` 负责文件树，`mini.sessions` 负责项目会话，Telescope / Trouble / Overseer 分别承担查找、诊断列表和任务运行。

## 依赖

- Neovim 0.12+
- `git`
- Windows 下使用 bookmarks 时建议通过 Scoop 安装 `sqlite-dll`，配置会自动使用 `~/scoop/apps/sqlite-dll/current/sqlite3.dll`
- `tree-sitter` CLI：`nvim-treesitter` 使用 `main` 分支，需要本机有 `tree-sitter` 命令（用于编译 parser）
- 可选：`rg`、`fd`、`cmake`，用于 Telescope / fzf-native 等插件获得更好体验
- 可选：`just`、`bun`、`npm`、`cargo` 等项目命令，用于 Overseer 自动发现并运行任务

## 插件概览

| 类别 | 插件 |
|------|------|
| 插件管理 | lazy.nvim |
| 启动页 / 文件树 | mini.nvim（starter、files、sessions、surround、pairs、move、align、bufremove） |
| 补全 | blink.cmp + minuet-ai.nvim + friendly-snippets |
| LSP | nvim-lspconfig + mason（lua_ls、rust_analyzer、clangd、ts_ls、eslint、jsonls、bashls、taplo） |
| 主题 | rose-pine（dawn 变体） |
| 查找 | telescope.nvim + fzf-native |
| 诊断 | trouble.nvim |
| Git | Neogit + gitsigns + diffview + aicommits（Codestral） |
| 任务 | overseer.nvim |
| 笔记 | Markdown + render-markdown.nvim |
| 终端 | toggleterm.nvim（自定义布局：水平贴底、垂直在右互不侵占） |
| 格式化 | conform.nvim |
| UI | noice.nvim（命令行 / 消息浮窗）、lualine.nvim（状态栏 / tabline）、render-markdown.nvim、markdown-plus.nvim |
| 书签 | bookmarks.nvim（按项目自动切换列表） |
| Treesitter | nvim-treesitter（main 分支）+ treesitter-context |
| 导航 | hop.nvim（普通文件按词跳转，部分特殊界面跨窗口按行跳转） |
| 按键 | which-key.nvim |
| Neovide | neov-ime.nvim（IME 管理） |

## 本地私密配置

私密配置放在 `lua/config/local.lua`，该文件已加入 `.gitignore`。

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
  notes = {
    root = "~/Dropbox/note",
    drawer_width = 48,
  },
  aicommits = {
    api_key = "your-codestral-api-key",
    endpoint = "https://codestral.mistral.ai/v1/chat/completions",
    model = "codestral-latest",
  },
  minuet = {
    api_key = "your-codestral-api-key",
    endpoint = "https://codestral.mistral.ai/v1/fim/completions",
    max_tokens = 256,
  },
}
```

LSP 诊断也可以通过项目内标记文件静音：在项目根或子目录放置 `.nvim-disable-lsp-diagnostics` 或 `.nvim/lsp-diagnostics-off`。跳转、补全、hover 等 LSP 能力仍然保留。

## LSP 配置

- `lua/lsp/init.lua` 是 LSP server 注册中心，统一维护启用的 server 名单。
- `nvim-lspconfig` 提供默认 `cmd`、`filetypes` 和项目根目录识别；`lua/lsp/servers/` 只保留本地覆盖，例如 `lua_ls.lua`、`clangd.lua`、`rust_analyzer.lua`。
- `lua/plugins/lsp.lua` 只负责插件接线：诊断显示、Mason 配置、启用 LSP 和 `LspAttach` 快捷键。

## 常用入口

### 文件 / Buffer

| 按键 | 功能 |
|------|------|
| `<leader>e` | 打开 / 关闭 mini.files 文件树 |
| `<leader>,` | Buffer 列表（Telescope picker） |
| `<leader>/` | 当前 buffer 内搜索 |
| `<leader>ff` | 查找文件 |
| `<leader>fh` | 帮助标签 |
| `<leader>fr` | 最近打开文件 |
| `<leader>fH` | 命令历史 |
| `<leader>fg` | 全局搜索（live grep） |
| `<leader>fw` | 搜索光标词 / 选区文本 |
| `<leader>x` | 关闭光标所在层级（窗口 / buffer / 特殊界面） |
| `<leader>X` | 强制删除当前 buffer |
| `<leader>bn` / `<leader>bp` | 下一个 / 上一个 buffer |

### LSP / 诊断 / 符号

| 按键 | 功能 |
|------|------|
| `K` | LSP hover |
| `gd` | 跳转定义 |
| `gD` | 跳转声明 |
| `gy` | 跳转类型定义 |
| `grr` | 引用列表（Trouble） |
| `gri` | 实现列表（Trouble） |
| `<leader>cr` | 重命名符号 |
| `<leader>ca` | 代码动作 |
| `<leader>sd` | 当前文件诊断（Trouble） |
| `<leader>sD` | 工作区诊断（Trouble） |
| `<leader>so` | 当前文件结构侧栏（Outline） |
| `<leader>ss` | 工作区符号搜索 |
| `]d` / `[d` | 下一条 / 上一条诊断并弹出浮窗 |

### Git

| 按键 | 功能 |
|------|------|
| `<leader>gg` | Neogit status |
| `<leader>gc` | Neogit commit |
| `<leader>gl` | Neogit log |
| `<leader>gh` | Stage hunk（normal / visual） |
| `<leader>gH` | Reset hunk（normal / visual） |
| `<leader>gp` | Preview hunk |
| `<leader>gb` | Blame line（完整信息） |
| `<leader>gB` | 切换当前行 blame 显示 |
| `]h` / `[h` | 下一个 / 上一个 hunk |

### 笔记

| 按键 | 功能 |
|------|------|
| `<leader>nn` | 打开 / 关闭全局 `index.md` 抽屉；从其它笔记入口切来时复用同一个右侧抽屉 |
| `<leader>ni` | 打开 / 关闭全局 `inbox.md` 抽屉；从其它笔记入口切来时复用同一个右侧抽屉 |
| `<leader>nj` | 打开 / 关闭当日 `journal/YYYY/MM/W/YYYY-MM-DD.md` 抽屉；从其它笔记入口切来时复用同一个右侧抽屉 |
| `:Notes` | 同 `<leader>nn`，打开 / 关闭全局 `index.md` 抽屉 |

### 终端

| 按键 | 功能 |
|------|------|
| `<leader>tt` | 切换默认终端（水平） |
| `<leader>th` | 新建水平终端（贴底） |
| `<leader>tv` | 新建垂直终端（右侧） |
| `<leader>to` | 终端选择器 |
| `<leader>tr` | 重命名终端 |
| `<leader>tn` | 外部终端 |

### 任务（Overseer）

| 按键 | 功能 |
|------|------|
| `<leader>jr` | 运行任务 |
| `<leader>jo` | 切换任务列表 |
| `<leader>jc` | 关闭任务列表 |
| `<leader>ja` | 任务动作 |
| `<leader>jf` | 打开最近失败任务输出 |
| `<leader>js` | 运行 ad-hoc shell 任务 |
| `<leader>jC` | 清除任务缓存 |

### 书签

| 按键 | 功能 |
|------|------|
| `<leader>mm` | 标记当前行 |
| `<leader>mo` | 跳转书签 |
| `<leader>mt` | 书签树视图 |
| `<leader>ma` | 书签动作菜单 |

### 其他

| 按键 | 功能 |
|------|------|
| `<leader>?</> | 查看当前 buffer 键位（which-key） |
| `<leader>cf` | 格式化当前文件 |
| `<leader>ft` | 搜索 TODO 注释 |
| `]t` / `[t` | 下一个 / 上一个 TODO 注释 |
| `[c` | 跳转到 Treesitter 上下文 |
| `s` | hop.nvim 按上下文跳转：普通文件按词，特殊界面按行；Neogit 未暂存/未跟踪文件行会优先 stage |
| `<leader>qq` / `<leader>qw` / `<leader>qQ` | 退出 / 保存退出 / 强制退出 |
| `:R` | 重载 Neovim 配置（热更新，不重启） |
| `:Starter` | 手动打开启动页 |

## 补全系统

- **blink.cmp** 作为补全引擎，自动来源包括 LSP、Minuet、路径和 buffer 内容。
- Minuet 候选通过 `minuet-ai.nvim` 的 blink native source 接入，使用 Codestral FIM；默认复用 `local.lua` 里 `aicommits` 的 key/model，也可用 `minuet.api_key` 单独覆盖，插入模式按 `Alt-y` 可手动请求 AI 补全。
- Markdown 文件额外启用 snippets 来源。
- 命令行补全：搜索命令（`/`、`?`）使用当前 buffer 内容；冒号命令同时补命令和已有文本。
- Noice 命令行浮窗位置由补全菜单感知，避免遮挡。

## 项目启动与会话

- 启动页展示最近路径和内置入口（Find file、New file、Open、Config、Quit）。
- 最近路径保存在 `~/.local/share/nvim/starter-recent-paths.json`，上限 100 条，重复路径自动去重并移到队首。
- 在最近路径上按 `<BS>` 可删除该条目，启动页即时刷新。
- `Open` 入口打开 home 目录的文件树，`Config` 入口打开 nvim 配置目录；这两个入口不写入最近路径。
- 打开目录时会先切换 cwd，再尝试恢复当前项目 session；没有 session 时打开 `mini.files`。
- home 目录作为 starter 入口页，不写入项目 session。
- Starter 的 `Open` 入口会临时启用 `mini.files` 中的 `<S-CR>`：只有最终确认打开的路径会写入最近路径，中间浏览目录不会污染记录。
- Session 写入前会过滤无意义 buffer，空 session 会被清理，避免下次恢复到空壳布局。

## 加载与保存约定

- `ConfigFilePost` 会在 UI 已进入且首个真实文件 buffer 出现后触发，用于延后加载 gitsigns、treesitter-context、todo-comments 等文件型插件。
- 自动保存覆盖以下场景：`InsertLeave`、`BufLeave`、`FocusLost`、`VimLeavePre`。只作用于正常、可写、有文件名且已修改的文件 buffer；terminal、help、quickfix、无名 buffer 和只读 buffer 不会被强行写盘。
- 读取和写入文件时会清理残留 `\r`，降低混合换行导致的 `^M` 噪音。

## Bookmarks

书签按当前 cwd 自动切换到同名项目列表，避免不同项目混用同一个 bookmarks 列表。树视图固定宽度为 50，并隐藏 number、signcolumn、foldcolumn 等额外栏位；目录折叠图标和书签图标会统一替换成更紧凑的样式。

## AI Commit

AI commit 使用 `404pilo/aicommits.nvim`，通过 OpenAI-compatible Chat Completions 接口连接 Codestral。

使用方式：

1. 在 Neogit 中 stage 需要提交的内容。
2. 按 `c` 打开 Neogit commit popup。
3. 在 `AI` 分组里按 `C` 执行 `AI Commit`。
4. 从生成结果中选择 commit message（默认生成 5 条候选）。

说明：

- `aicommits.nvim` 的 Neogit integration 已开启，用于提交后刷新 Neogit。
- 插件自带的 Neogit status 页独立 `C` 映射已关闭。
- AI action 由 `lua/plugins/neogit.lua` 注入到 Neogit commit popup。

## Neogit 仓库识别

`:Neogit` 和 `<leader>gg` / `<leader>gc` / `<leader>gl` 会优先从当前 buffer 的文件目录执行 `git rev-parse --show-toplevel`，再回退到当前 cwd。
需要手动指定仓库时，仍然可以使用 Neogit 原生参数，例如 `:Neogit cwd=/path/to/repo`。

## Diffview

Diffview 关闭交给全局 `<leader>x`，在 Diffview tab 内会调用 Diffview 自己的关闭流程。

## 终端布局

toggleterm 使用自定义窗口切分策略：

- **水平终端**：全部在底部横条内，内部左右切分，贴编辑器底部、全宽。
- **垂直终端**：全部在右侧竖条内，内部上下切分。竖条只占 content 区域高度，底部让位给水平终端。
- 同一方向的终端共享区域，不会互相抢占；`<leader>to` 可打开终端选择器。
- 终端尺寸随窗口缩放，但保留最低可用尺寸（水平 ≥12 行，垂直 ≥30 列）。

## Overseer 任务

`<leader>jr` 会从当前文件目录开始搜索 Overseer 模板；当前 buffer 不是普通文件时回退到 cwd。任务模板和 action 选择使用 Telescope picker，仍保留 Overseer 自动发现的所有 providers。

任务启动时不会默认展开底部输出；失败后会自动打开输出窗口，或者用 `<leader>jf` 随时打开最近失败任务的输出。

## 界面约定

- 主题使用 `rose-pine-dawn`（亮色变体）。
- 所有浮窗尽量复用 `lua/util/float.lua` 的单线边框和高亮约定，Telescope、Noice、LSP hover、diagnostic float、blink 补全菜单、which-key、Overseer 等入口保持统一。
- lualine statusline 使用紧凑模式标签（`N`、`I`、`V`、`T` 等）；branch、diagnostics 和 filetype 会按窗口宽度条件显示，最右侧显示当前 OS 图标。
- 顶部 tabline 左侧保留独立 Vim 图标区，buffer 列表只显示简洁名称，并用 `●` 标记已修改 buffer。
- `signcolumn` 固定保留（`yes`），避免诊断、git sign 或书签 sign 出现时正文左右跳动。gitsigns 通过自定义 `statuscolumn` 在行号右侧显示 git 标记。
- Treesitter 折叠行使用自定义格式（`◇` 前缀 + 首行预览 + 尾部信息）。
- Markdown 链接相关快捷键放在 `after/ftplugin/markdown.lua`，Lua 文件局部设置放在 `after/ftplugin/lua.lua`。
- Markdown 笔记默认使用全局 `~/Dropbox/note` 根目录，可通过 `lua/config/local.lua` 的 `notes.root` 覆盖；journal 按 `journal/YYYY/MM/W/YYYY-MM-DD.md` 分层；右侧抽屉 buffer 不进入普通 buffer 列表，避免污染项目工作流。
- Noice 在补全菜单显示时自动抑制 LSP signature popup，避免浮窗抢焦点。

## Treesitter

- 使用 nvim-treesitter `main` 分支，通过 `FileType` autocmd 按已配置 parser 显式启动高亮。
- 预装 parser：markdown、markdown_inline、html、lua、vim、vimdoc、rust、toml、c、cpp、cmake、gn、ninja、bash、json、typescript、javascript。
- 每次 `build`（插件安装/更新时）自动更新全部已配置 parser。
- 启动后补装可能缺失的 parser。
- `:TSInstallConfigParsers` 可手动安装全部已配置 parser。

## Neovide

当 `vim.g.neovide` 为 `true` 时自动加载 `lua/config/neovide.lua`：

- 字体：Maple Mono NF + LXGW Bright 中文回退（Windows 17pt / macOS 21pt）
- 刷新率 144Hz，idle 降至 5Hz
- 亮色主题，光标动画 "pixiedust"
- 标题栏显示当前工作目录
- 载入 neov-ime.nvim 管理 IME

## 配置热更新

`:R` 命令会清除 `config`、`custom`、`libs`、`lsp`、`plugins`、`util` 命名空间下的已加载模块，然后重新 source `init.lua`，实现不重启 Neovim 的配置热更新。Lazy 已初始化时只刷新插件规格，不重复执行 `lazy.setup()`。

## Headless 验证

关键交互边界可以用 Neovim headless 脚本验证：

```sh
nvim --headless -u NONE -i NONE -n -S tests/headless/mini_behaviors.lua +qa
```

## 结构收口补充

- `lua/state/lifecycle.lua` 持有生命周期状态，热重载时不需要回写全局变量。

## 结构收口

- `lua/config/lifecycle.lua` 统一管理 `ConfigUiReady` / `ConfigBackground` / `ConfigFilePost`。
- `lua/plugins/mini/project.lua` 统一 recent、session、home 规则。
- `lua/patches/` 统一收口 blink / noice / bookmarks / overseer / toggleterm 的内部 patch。
- 细节说明见 `doc/lifecycle-and-patches.md`。
