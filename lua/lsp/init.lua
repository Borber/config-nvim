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
