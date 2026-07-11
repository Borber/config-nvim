local function local_aicommits_config()
  local local_config = require("config.local")
  assert(type(local_config) == "table", "config.local must return a table")

  return local_config.aicommits or {}
end

return {
  "404pilo/aicommits.nvim",
  cmd = { "AICommit", "AICommitHealth", "AICommitDebug" },
  opts = function()
    local local_config = local_aicommits_config()
    local float = require("util.float")

    return {
      active_provider = "openai",
      providers = {
        openai = {
          enabled = true,
          -- 这里复用 OpenAI-compatible provider，但实际请求发到 Codestral。
          -- API key 从 lua/config/local.lua 读取；该文件不会被 Git 同步。
          api_key = local_config.api_key,
          endpoint = local_config.endpoint,
          model = local_config.model,
          max_length = 72,
          generate = 5,
          temperature = 0.3,
          max_tokens = 500,
        },
      },
      large_diff = {
        -- 官方主线已改为 large_diff 配置；保持总是先做摘要再生成 commit message。
        mode = "always",
        chunk_chars = 6000,
        max_chunks_per_file = 10,
      },
      ui = {
        use_custom_picker = true,
        picker = {
          width = 0.4,
          height = 0.3,
          border = float.border,
        },
      },
      integrations = {
        neogit = {
          -- 保留提交后的 Neogit 刷新，但不占用 status 页的独立 `C`。
          -- AI action 由 neogit.lua 注入到 NeogitCommitPopup。
          enabled = true,
          mappings = {
            enabled = false,
          },
        },
      },
    }
  end,
}
