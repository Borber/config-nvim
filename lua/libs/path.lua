-- ============================================
-- 路径规范化与文件系统查询工具
-- 统一 Windows/Unix 路径格式，提供 stat 缓存、
-- 类型判断、URI 过滤等基础能力。
-- ============================================
local M = {}

local function is_uri(path)
  if type(path) ~= "string" then
    return false
  end

  -- Windows drive paths 可能写成 `C:/...` 或 `C://...`，不能误判成 URI。
  if path:match("^[A-Za-z]:[/\\]") or path:match("^[A-Za-z]://") then
    return false
  end

  return path:match("^%w[%w+.-]*://") ~= nil
end

local function trim_trailing_slash(path)
  if path ~= nil and #path > 3 then
    return (path:gsub("/+$", ""))
  end
  return path
end

local function cached_stat(cache, path)
  if cache == nil then
    return nil, false
  end

  local cached = cache[path]
  if cached == nil then
    return nil, false
  end

  return cached ~= false and cached or nil, true
end

local function stat_normalized(path, cache)
  local stat, found = cached_stat(cache, path)
  if found then
    return stat
  end

  stat = vim.uv.fs_stat(path)
  if cache ~= nil then
    cache[path] = stat or false
  end

  return stat
end

-- Windows/Unix 路径统一成 /，并去掉多余尾斜杠，方便后续前缀比较。
function M.canonical(path)
  if path == nil or path == "" then
    return path
  end

  local normalized = vim.fs.normalize(path):gsub("\\", "/")
  normalized = normalized:gsub("^([A-Za-z]:)/+", "%1/")

  return trim_trailing_slash(normalized)
end

function M.local_normalized(path)
  -- 只接受本地文件路径；URI 交给对应插件处理，不参与本地路径比较。
  if not path or path == "" or is_uri(path) then
    return nil
  end

  return M.canonical(path)
end

function M.absolute(path)
  -- 用 Vim 的 :p 规则展开相对路径，保持与 edit/mksession 行为一致。
  if path == nil or path == "" then
    return nil
  end

  return vim.fn.fnamemodify(path, ":p")
end

function M.stat(path, cache)
  -- 单次操作内可传入 cache 表复用 fs_stat；不做全局缓存，避免路径变化后 UI 长时间陈旧。
  local normalized = M.local_normalized(path)
  if normalized == nil then
    return nil
  end

  return stat_normalized(normalized, cache)
end

function M.kind(path, cache)
  local normalized = M.local_normalized(path)
  if normalized == nil then
    return nil
  end

  local stat = stat_normalized(normalized, cache)
  if stat == nil then
    return "missing"
  end

  return stat.type or "other"
end

function M.exists(path, cache)
  local kind = M.kind(path, cache)
  return kind ~= nil and kind ~= "missing"
end

function M.is_directory(path, cache)
  return M.kind(path, cache) == "directory"
end

function M.is_file(path, cache)
  -- 历史调用点把 is_file 当成“真实可读文件”判断；先用 stat/kind 过滤，再集中做可读性检查。
  local normalized = M.local_normalized(path)
  if normalized == nil then
    return false
  end

  local stat = stat_normalized(normalized, cache)
  return stat ~= nil and stat.type == "file" and vim.fn.filereadable(normalized) == 1
end

function M.basename(path)
  -- 同时兼容 Windows 和 Unix 分隔符，并忽略尾部斜杠。
  if path == nil or path == "" then
    return nil
  end

  local trimmed = path:gsub("[/\\]+$", "")
  local name = trimmed:match("([^/\\]+)$")

  return name ~= nil and name ~= "" and name or nil
end

function M.canonical_absolute(path)
  -- 用于跨来源路径比较：先 expand，再转绝对路径，再统一分隔符/尾斜杠。
  if path == nil or path == "" then
    return nil
  end

  local expanded = vim.fn.expand(path)
  if expanded == "" then
    expanded = path
  end

  return M.canonical(vim.fn.fnamemodify(expanded, ":p"))
end

return M
