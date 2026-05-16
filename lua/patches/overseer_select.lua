-- ============================================
-- Overseer select 路由
-- ============================================
local M = {}

local function default_select(items, opts, on_choice)
  require("util.fzf_picker").select(items, opts, on_choice)
end

function M.is_overseer_kind(opts)
  return opts and type(opts.kind) == "string" and vim.startswith(opts.kind, "overseer")
end

function M.apply(select_fn)
  if vim.ui._config_overseer_patched then
    return
  end

  select_fn = select_fn or default_select
  vim.ui._config_overseer_original_select = vim.ui._config_overseer_original_select or vim.ui.select

  local original_select = vim.ui._config_overseer_original_select
  rawset(vim.ui, "select", function(items, opts, on_choice)
    if M.is_overseer_kind(opts) then
      select_fn(items, opts, on_choice)
      return
    end

    return original_select(items, opts, on_choice)
  end)

  vim.ui._config_overseer_patched = true
end

return M
