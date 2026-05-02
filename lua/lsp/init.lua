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
  local ok, config = pcall(require, "lsp.servers." .. name)
  if not ok then
    error(("Failed to load LSP server config %q: %s"):format(name, config))
  end

  return config or {}
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
