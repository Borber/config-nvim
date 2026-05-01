local M = {}

-- 项目里放置这些标记文件后，只静音诊断；跳转、补全、hover 等 LSP 能力仍然保留。
local diagnostic_mute_markers = {
  ".nvim-disable-lsp-diagnostics",
  ".nvim/lsp-diagnostics-off",
}

local local_config

local function local_lsp_config()
  -- 本地配置可能包含私有路径，按需读取并缓存，避免 LSP attach 时反复 require。
  if local_config ~= nil then
    return local_config
  end

  local config = require("config.local")
  assert(type(config) == "table", "config.local must return a table")

  local_config = config.lsp or {}
  return local_config
end

local function normalize_path(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  return vim.fs.normalize(path)
end

local function path_contains(root, path)
  -- 统一规范化后再做前缀判断，避免 Windows 反斜杠导致静音根目录匹配失败。
  root = normalize_path(root)
  path = normalize_path(path)

  if root == nil or path == nil then
    return false
  end

  return path == root or vim.startswith(path, root .. "/")
end

local function client_root(client, bufnr)
  -- 优先相信 server 自己的 root_dir；没有时再从 workspace_folders 里选最贴近 buffer 的根。
  if client and client.config and type(client.config.root_dir) == "string" then
    return normalize_path(client.config.root_dir)
  end

  local bufname = normalize_path(vim.api.nvim_buf_get_name(bufnr))

  if client and type(client.workspace_folders) == "table" then
    local best_root

    for _, folder in ipairs(client.workspace_folders) do
      local root = normalize_path(vim.uri_to_fname(folder.uri))

      if path_contains(root, bufname) and (best_root == nil or #root > #best_root) then
        best_root = root
      end
    end

    if best_root ~= nil then
      return best_root
    end
  end

  return bufname and vim.fs.root(bufname, { ".git" }) or nil
end

local function has_diagnostic_mute_marker(bufnr)
  local bufname = normalize_path(vim.api.nvim_buf_get_name(bufnr))
  local dir = bufname and vim.fs.dirname(bufname) or nil

  if dir == nil then
    return false
  end

  local markers = local_lsp_config().diagnostic_mute_markers or diagnostic_mute_markers

  -- 从当前文件目录一路向上查找标记文件，让项目根或子目录都能局部静音诊断。
  while dir ~= nil do
    for _, marker in ipairs(markers) do
      if vim.uv.fs_stat(vim.fs.joinpath(dir, marker)) ~= nil then
        return true
      end
    end

    local parent = vim.fs.dirname(dir)
    if parent == nil or parent == dir then
      break
    end

    dir = parent
  end

  return false
end

function M.muted(bufnr, client)
  local bufname = normalize_path(vim.api.nvim_buf_get_name(bufnr))
  local root = client_root(client, bufnr)

  -- diagnostic_mute_roots 适合放机器私有的大项目路径；marker 文件适合随项目显式声明。
  for _, muted_root in ipairs(local_lsp_config().diagnostic_mute_roots or {}) do
    if path_contains(muted_root, root) or path_contains(muted_root, bufname) then
      return true
    end
  end

  return has_diagnostic_mute_marker(bufnr)
end

function M.reset(client_id, bufnr)
  -- push/pull 两套诊断命名空间都清掉，防止 server 切协议后残留旧诊断。
  vim.diagnostic.reset(vim.lsp.diagnostic.get_namespace(client_id, false), bufnr)
  vim.diagnostic.reset(vim.lsp.diagnostic.get_namespace(client_id, true), bufnr)
end

function M.wrap_handlers(client)
  -- 每个 client 只包一层，避免配置热重载或重复 attach 后 handler 嵌套调用。
  if client == nil or client._config_diagnostic_handlers_wrapped then
    return
  end

  client._config_diagnostic_handlers_wrapped = true
  client.handlers = client.handlers or {}

  local publish_handler = client.handlers["textDocument/publishDiagnostics"] or vim.lsp.handlers["textDocument/publishDiagnostics"]

  -- 兼容传统 publishDiagnostics：拦截后清空当前 buffer 的诊断，但不关闭 client。
  client.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    local bufnr = result and result.uri and vim.uri_to_bufnr(result.uri) or nil

    if bufnr ~= nil and M.muted(bufnr, client) then
      M.reset(ctx.client_id, bufnr)
      return
    end

    return publish_handler(err, result, ctx, config)
  end

  local pull_handler = client.handlers["textDocument/diagnostic"] or vim.lsp.handlers["textDocument/diagnostic"]

  -- 兼容 pull diagnostics：一些新 server 会走 textDocument/diagnostic。
  client.handlers["textDocument/diagnostic"] = function(err, result, ctx, config)
    local bufnr = ctx.bufnr

    if bufnr ~= nil and M.muted(bufnr, client) then
      M.reset(ctx.client_id, bufnr)
      return
    end

    return pull_handler(err, result, ctx, config)
  end
end

return M
