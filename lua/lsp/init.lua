-- LSP 服务器注册中心
-- 统一管理所有语言服务器的配置声明，供 plugins/lsp.lua 调用 vim.lsp.enable()。
-- 每个服务器配置按语言拆分到 lua/lsp/servers/ 目录。

local M = {}

-- 需要 Mason 自动安装的纯声明服务器
M.default_servers = {}

-- 需要额外配置的自定义服务器（如 clangd、rust_analyzer、lua_ls 等）
M.custom_servers = {}

function M.setup()
  -- 子类通过 setup() 注册 default_servers 和 custom_servers 条目，
  -- 调用方通过 vim.lsp.config() + vim.lsp.enable() 激活。
end

return M
