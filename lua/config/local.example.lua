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

  orgmode = {
    -- 全局 Org 笔记本根目录；不填时默认使用 ~/Dropbox/org。
    root = "~/Dropbox/org",
    drawer_width = 48,
  },

  aicommits = {
    -- Codestral API key。不要把真实 key 写进 example 文件。
    api_key = "your-codestral-api-key",

    -- 一般不需要改；留在这里方便以后切换兼容 OpenAI Chat Completions 的服务。
    endpoint = "https://codestral.mistral.ai/v1/chat/completions",
    model = "codestral-latest",
  },
}
