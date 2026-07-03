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
  "taplo",
}

local function load_override(name)
  local config = require("lsp.servers." .. name)
  if type(config) ~= "table" then
    error(("LSP server override %q must return a table"):format(name))
  end

  return config
end

local function configure_default_capabilities()
  local capabilities = {
    textDocument = {
      completion = {
        completionItem = {
          snippetSupport = true,
        },
      },
      foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      },
    },
  }

  local ok, blink = pcall(require, "blink.cmp")
  if ok and type(blink.get_lsp_capabilities) == "function" then
    capabilities = blink.get_lsp_capabilities(capabilities)
  end

  -- ufo 的 lsp provider 需要 foldingRange capability；同时在 LSP 真正启动前
  -- 主动合并 blink 的 completion capabilities，避免 InsertEnter 才加载补全时
  -- 首个 taplo/rust-analyzer client 缺少 snippet/schema 相关协商能力。
  vim.lsp.config("*", {
    capabilities = capabilities,
  })
end

function M.configure()
  configure_default_capabilities()

  for _, name in ipairs(override_names) do
    vim.lsp.config(name, load_override(name))
  end
end

---@return string[]
function M.names()
  return vim.deepcopy(server_names)
end

return M
