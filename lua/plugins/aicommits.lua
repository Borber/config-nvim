local function local_aicommits_config()
  local ok, local_config = pcall(require, "config.local")
  if not ok or type(local_config) ~= "table" then
    return {}
  end

  return local_config.aicommits or {}
end

return {
  "404pilo/aicommits.nvim",
  cmd = { "AICommit", "AICommitHealth", "AICommitDebug" },
  keys = {
    { "<leader>ha", "<Cmd>AICommit<CR>", desc = "AI commit" },
    { "<leader>hA", "<Cmd>AICommitHealth<CR>", desc = "AI commit health" },
  },
  opts = function()
    local local_config = local_aicommits_config()

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
          generate = 3,
          temperature = 0.3,
          max_tokens = 200,
        },
      },
      ui = {
        use_custom_picker = true,
        picker = {
          width = 0.4,
          height = 0.3,
          border = "rounded",
        },
      },
      integrations = {
        neogit = {
          enabled = true,
          mappings = {
            enabled = true,
            key = "C",
          },
        },
      },
    }
  end,
}
