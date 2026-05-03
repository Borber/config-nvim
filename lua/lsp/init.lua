-- ============================================
-- LSP Server 注册表
-- 集中声明所有启用的 language server 名称，
-- 从 lsp/servers/ 目录加载各自的配置表。
-- ============================================
-- nvim-lspconfig owns server defaults; this module only lists enabled servers
-- and applies local overrides for the few servers that need them.
---@class ConfigLspRegistry
---@field configure fun()
---@field names fun(): string[]

local M = {}

local server_names = {
  "lua_ls",
  "rust_analyzer",
  "clangd",
  "ts_ls",
  "eslint",
  "jsonls",
  "bashls",
  "taplo",
}

local override_names = {
  "lua_ls",
  "rust_analyzer",
  "clangd",
}

local function load_override(name)
  local config = require("lsp.servers." .. name)
  if type(config) ~= "table" then
    error(("LSP server override %q must return a table"):format(name))
  end

  return config
end

function M.configure()
  for _, name in ipairs(override_names) do
    vim.lsp.config(name, load_override(name))
  end
end

---@return string[]
function M.names()
  return vim.deepcopy(server_names)
end

return M
