local function local_aicommits_config()
  local local_config = require("config.local")
  assert(type(local_config) == "table", "config.local must return a table")

  return local_config.aicommits or {}
end

return {
  "borber/aicommits.nvim",
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
      input = {
        mode = "rich",
        rich = {
          chunk_chars = 6000,
          max_chunks_per_file = 10,
        },
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
          -- 打开内置 Neogit refresh，但不使用它的 status 页独立 C 映射。
          -- AI action 仍由 neogit.lua 注入到 NeogitCommitPopup。
          enabled = true,
        },
      },
    }
  end,
}
