-- ============================================
-- LSP 服务与工具检查
-- ============================================
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

local function configure_default_capabilities()
  -- Neovim 0.12 已提供 snippet 等默认能力，这里只补齐 Blink 的协商差异。
  vim.lsp.config("*", {
    capabilities = {
      textDocument = {
        completion = {
          completionItem = {
            insertTextModeSupport = { valueSet = { 1 } },
            resolveSupport = { properties = { "documentation", "detail", "additionalTextEdits", "command", "data" } },
          },
          completionList = { itemDefaults = { "commitCharacters", "editRange", "insertTextFormat", "insertTextMode", "data" } },
          insertTextMode = 1,
        },
      },
    },
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
