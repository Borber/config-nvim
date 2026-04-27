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
  init = function()
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("ConfigAicommitsNeogit", { clear = true }),
      pattern = "NeogitStatus",
      callback = function(event)
        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(event.buf) then
            return
          end

          -- aicommits.nvim 自带 Neogit integration 会在提交后强制刷新 Neogit；
          -- 那个异步刷新偶尔会碰到 Neogit 的只读 status buffer，导致 E21/invalid job id。
          -- 这里自己只保留触发键位，把提交后的刷新交给用户按 Neogit 原生刷新键完成。
          vim.keymap.set("n", "C", "<Cmd>AICommit<CR>", {
            buffer = event.buf,
            desc = "AI commit",
            silent = true,
          })
        end)
      end,
    })
  end,
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
          -- 禁用插件内置集成，避免提交成功后自动 refresh 触发 Neogit 异步报错。
          -- Neogit status buffer 的 C 键位由上面的 autocmd 单独注册。
          enabled = false,
          mappings = {
            enabled = false,
            key = "C",
          },
        },
      },
    }
  end,
}
