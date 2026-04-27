# config-nvim
# config-nvim

个人 Neovim 配置，使用 `lazy.nvim` 管理插件。

## 依赖

- Neovim 0.11+
- `git`
- `tree-sitter`：`nvim-treesitter` 使用 `main` 分支，需要本机有 `tree-sitter` 命令
- 可选：`rg`、`fd`、`cmake`，用于 Telescope / fzf-native 等插件获得更好体验

## 本地私密配置

私密配置放在 `lua/config/local.lua`，该文件已加入 `.gitignore`，不会被 Git 同步。

第一次使用时复制示例文件：

```sh
cp lua\config\local.example.lua lua\config\local.lua
```

然后在 `lua/config/local.lua` 里填写本机配置，例如 Codestral API key：

```lua
return {
  aicommits = {
    api_key = "your-codestral-api-key",
    endpoint = "https://codestral.mistral.ai/v1/chat/completions",
    model = "codestral-latest",
  },
}
```

不要把真实 key 写进 `local.example.lua`。

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

## Neogit 仓库识别

`:Neogit` 和 `<leader>hg` / `<leader>hc` / `<leader>hl` 会优先从当前 buffer 的文件目录执行 `git rev-parse --show-toplevel`，再回退到当前 cwd。
需要手动指定仓库时，仍然可以使用 Neogit 原生参数，例如 `:Neogit cwd=/path/to/repo`。

个人 Neovim 配置，使用 `lazy.nvim` 管理插件。

## 依赖

- Neovim 0.11+
- `git`
- `tree-sitter`：`nvim-treesitter` 使用 `main` 分支，需要本机有 `tree-sitter` 命令
- 可选：`rg`、`fd`、`cmake`，用于 Telescope / fzf-native 等插件获得更好体验

## 本地私密配置

私密配置放在 `lua/config/local.lua`，该文件已加入 `.gitignore`，不会被 Git 同步。

第一次使用时复制示例文件：

```sh
cp lua\config\local.example.lua lua\config\local.lua
```

然后在 `lua/config/local.lua` 里填写本机配置，例如 Codestral API key：

```lua
return {
  aicommits = {
    api_key = "your-codestral-api-key",
    endpoint = "https://codestral.mistral.ai/v1/chat/completions",
    model = "codestral-latest",
  },
}
```

不要把真实 key 写进 `local.example.lua`。

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

## Neogit 仓库识别

`:Neogit` 和 `<leader>hg` / `<leader>hc` / `<leader>hl` 会优先从当前 buffer 的文件目录执行 `git rev-parse --show-toplevel`，再回退到当前 cwd。
需要手动指定仓库时，仍然可以使用 Neogit 原生参数，例如 `:Neogit cwd=/path/to/repo`。
