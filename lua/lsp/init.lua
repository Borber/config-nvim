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
local tools = require("config.tools")

local server_names = {
  "lua_ls",
  "rust_glancer",
  "clangd",
  "ts_ls",
  "eslint",
  "jsonls",
  "bashls",
  "taplo",
}

local override_names = {
  "lua_ls",
  "rust_glancer",
  "clangd",
  "jsonls",
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
  -- 首个 taplo/Glancer client 缺少 snippet/schema 相关协商能力。
  vim.lsp.config("*", {
    capabilities = capabilities,
  })
end

local function guard_server_command(name)
  local config = vim.lsp.config[name]
  if type(config.cmd) ~= "function" then
    return
  end

  local root_dir = config.root_dir
  local command = assert(tools.server_commands[name], "Missing LSP tool declaration: " .. name)

  -- 函数形式的 cmd 会绕过 Neovim 的可执行检查；等上游识别项目根后再检查，保留项目本地服务器。
  vim.lsp.config(name, {
    root_dir = function(bufnr, on_dir)
      local function on_available(root)
        if tools.available(command, root) then
          on_dir(root)
        else
          tools.warn_missing(command)
        end
      end

      if type(root_dir) == "function" then
        root_dir(bufnr, on_available)
      else
        on_available(root_dir or (config.root_markers and vim.fs.root(bufnr, config.root_markers)))
      end
    end,
  })
end

local function check_buffer_tools(bufnr)
  local filetype = vim.bo[bufnr].filetype
  for _, name in ipairs(server_names) do
    local config = vim.lsp.config[name]
    if vim.tbl_contains(config.filetypes or {}, filetype) and type(config.cmd) == "table" and not tools.available(config.cmd[1]) then
      tools.warn_missing(config.cmd[1])
    end
  end
end

function M.configure()
  configure_default_capabilities()

  for _, name in ipairs(override_names) do
    vim.lsp.config(name, load_override(name))
  end

  for _, name in ipairs(server_names) do
    guard_server_command(name)
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ConfigLspTools", { clear = true }),
    callback = function(event)
      check_buffer_tools(event.buf)
    end,
    desc = "Check language server commands before starting",
  })
  check_buffer_tools(vim.api.nvim_get_current_buf())
end

---@return string[]
function M.names()
  return vim.deepcopy(server_names)
end

return M
