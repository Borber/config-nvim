-- ============================================
-- LSP Server 注册表
-- 集中声明所有启用的 language server 名称，
-- 从 lsp/servers/ 目录加载各自的配置表。
-- ============================================
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

local function load_server(name)
  local config = require("lsp.servers." .. name)
  if type(config) ~= "table" then
    error(("LSP server config %q must return a table"):format(name))
  end

  return config
end

function M.servers()
  local servers = {}

  for _, name in ipairs(server_names) do
    servers[name] = load_server(name)
  end

  return servers
end

function M.names()
  return vim.deepcopy(server_names)
end

return M
