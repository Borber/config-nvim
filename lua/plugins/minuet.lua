local function read_local_config()
  local ok, local_config = pcall(require, "config.local")
  if not ok or type(local_config) ~= "table" then
    return {}
  end

  return local_config
end

local function is_real_secret(value)
  return type(value) == "string" and value ~= "" and not value:match("^your%-")
end

local function local_api_key(value)
  return function()
    if is_real_secret(value) then
      return value
    end

    return nil
  end
end

local function codestral_fim_endpoint(endpoint)
  if type(endpoint) ~= "string" or endpoint == "" then
    return "https://codestral.mistral.ai/v1/fim/completions"
  end

  return endpoint:gsub("/chat/completions$", "/fim/completions")
end

local function local_minuet_config(local_config)
  local aicommits_config = type(local_config.aicommits) == "table" and local_config.aicommits or nil
  local minuet_config = {}

  if aicommits_config then
    minuet_config = {
      provider = "codestral",
      api_key = aicommits_config.api_key,
      endpoint = codestral_fim_endpoint(aicommits_config.endpoint),
      model = aicommits_config.model,
    }
  end

  if type(local_config.minuet) == "table" then
    minuet_config = vim.tbl_deep_extend("force", minuet_config, local_config.minuet)
  end

  minuet_config.provider = "codestral"
  return minuet_config
end

local function minuet_overrides(minuet_config)
  local overrides = vim.deepcopy(minuet_config)
  overrides.provider = nil
  overrides.api_key = nil
  overrides.endpoint = nil
  overrides.model = nil
  overrides.name = nil
  overrides.stop = nil
  overrides.max_tokens = nil
  overrides.top_p = nil

  return overrides
end

local function provider_options(minuet_config)
  return {
    codestral = {
      model = minuet_config.model or "codestral-latest",
      end_point = codestral_fim_endpoint(minuet_config.endpoint),
      api_key = local_api_key(minuet_config.api_key),
      optional = {
        stop = minuet_config.stop,
        max_tokens = minuet_config.max_tokens or 256,
        top_p = minuet_config.top_p,
      },
    },
  }
end

return {
  "milanglacier/minuet-ai.nvim",
  event = "InsertEnter",
  opts = function()
    local local_config = read_local_config()
    local minuet_config = local_minuet_config(local_config)

    local defaults = {
      provider = "codestral",
      blink = {
        enable_auto_complete = true,
      },
      cmp = {
        enable_auto_complete = false,
      },
      lsp = {
        enabled_ft = {},
        completion = {
          enable = false,
        },
        inline_completion = {
          enable = false,
        },
      },
      virtualtext = {
        auto_trigger_ft = {},
      },
      provider_options = provider_options(minuet_config),
    }

    return vim.tbl_deep_extend("force", defaults, minuet_overrides(minuet_config))
  end,
}
