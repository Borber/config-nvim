-- ============================================
-- LSP 诊断静音管理
-- 支持按项目目录或标记文件静音诊断输出，
-- 保留 LSP 跳转/补全/hover 等其他能力。
-- ============================================
local M = {}

-- 项目里放置这些标记文件后，只静音诊断；跳转、补全、hover 等 LSP 能力仍然保留。
local diagnostic_mute_markers = {
  ".nvim-disable-lsp-diagnostics",
  ".nvim/lsp-diagnostics-off",
}

local path_util = require("libs.path")
local local_config
local diagnostic_mute_marker_cache = {}

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
  return path_util.canonical(path_util.local_normalized(path))
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

local function stat_token(path)
  local stat = path_util.stat(path)
  if stat == nil then
    return path .. ":missing"
  end

  local mtime = stat.mtime or {}
  return table.concat({
    path,
    stat.type or "",
    tostring(stat.size or 0),
    tostring(mtime.sec or 0),
    tostring(mtime.nsec or 0),
  }, ":")
end

local function marker_parent_token(dir, marker)
  local marker_parent = normalize_path(vim.fs.dirname(vim.fs.joinpath(dir, marker)))
  if marker_parent == nil or marker_parent == dir then
    return nil
  end

  return stat_token(marker_parent)
end

local function marker_cache_token(dir, markers)
  -- 嵌套 marker（例如 .nvim/lsp-diagnostics-off）变更时，变的是 marker 父目录的 mtime，
  -- 不一定是项目根目录 mtime；token 同时纳入这些父目录才能避免正缓存变陈旧。
  local tokens = { stat_token(dir) }

  for _, marker in ipairs(markers) do
    local token = marker_parent_token(dir, marker)
    if token ~= nil then
      table.insert(tokens, token)
    end
  end

  return table.concat(tokens, "|")
end

local function parent_dir(dir)
  local parent = vim.fs.dirname(dir)
  if parent == nil or parent == dir then
    return nil
  end

  return parent
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
    local token = marker_cache_token(dir, markers)
    local cache_key = dir .. "|" .. table.concat(markers, "\0")
    local cached = diagnostic_mute_marker_cache[cache_key]
    if cached ~= nil and cached.token == token then
      if cached.value then
        return true
      end

      dir = parent_dir(dir)
    else
      local muted_here = false
      for _, marker in ipairs(markers) do
        if path_util.exists(vim.fs.joinpath(dir, marker)) then
          muted_here = true
          break
        end
      end

      diagnostic_mute_marker_cache[cache_key] = {
        token = token,
        value = muted_here,
      }

      if muted_here then
        return true
      end

      dir = parent_dir(dir)
    end
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
