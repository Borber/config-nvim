-- 复制为 lua/config/local.lua 后填写本机私密配置。
-- local.lua 已加入 .gitignore，不会被 Git 同步。
return {
  aicommits = {
    -- Codestral API key。不要把真实 key 写进 example 文件。
    api_key = "your-codestral-api-key",

    -- 一般不需要改；留在这里方便以后切换兼容 OpenAI Chat Completions 的服务。
    endpoint = "https://codestral.mistral.ai/v1/chat/completions",
    model = "codestral-latest",
  },
}
