-- 复制为 lua/config/local.lua 后填写本机私密配置。
-- local.lua 已加入 .gitignore，不会被 Git 同步。
return {
  lsp = {
    -- 不想在项目里放标记文件时，可以在这里按路径静音 LSP 诊断。
    -- 跳转、补全、hover 仍然保留。
    diagnostic_mute_roots = {
      -- "/path/to/large/project",
    },
  },

  notes = {
    -- 全局 Markdown 笔记根目录；不填时默认使用 ~/Dropbox/note。
    root = "~/Dropbox/note",
    drawer_width = 48,
  },

  input_method = {
    -- 终端 Neovim 下按模式切换系统输入法；启动和聚焦时先切英文。
    -- 没有可用命令时自动不启用。
    -- Linux/Fcitx5 默认使用 fcitx5-remote + keyboard-us。
    -- macOS 可用 macism 或 im-select 查看本机英文输入源 ID 后覆盖。
    enabled = true,
    -- default_command = "macism",
    -- default_im_select = "com.apple.keylayout.ABC",
  },

  aicommits = {
    -- Codestral API key。不要把真实 key 写进 example 文件。
    api_key = "your-codestral-api-key",

    -- 一般不需要改；留在这里方便以后切换兼容 OpenAI Chat Completions 的服务。
    endpoint = "https://codestral.mistral.ai/v1/chat/completions",
    model = "codestral-latest",
  },

  minuet = {
    -- Minuet 专属 Codestral FIM 补全配置。
    -- 这里不读取环境变量，key 应直接放在 local.lua。
    api_key = "your-codestral-fim-api-key",
    endpoint = "https://codestral.mistral.ai/v1/fim/completions",
    model = "codestral-latest",
    max_tokens = 256,
  },
}
