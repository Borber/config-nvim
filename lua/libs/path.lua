local M = {}

local function is_uri(path)
  return type(path) == "string" and path:match("^%w[%w+.-]*://") ~= nil
end

local function trim_trailing_slash(path)
  if path ~= nil and #path > 3 then
    return (path:gsub("/+$", ""))
  end
  return path
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

  return vim.fs.normalize(path)
end

function M.absolute(path)
  -- 用 Vim 的 :p 规则展开相对路径，保持与 edit/mksession 行为一致。
  if path == nil or path == "" then
    return nil
  end

  return vim.fn.fnamemodify(path, ":p")
end

function M.is_directory(path)
  -- 文件/目录存在性判断集中在这里，调用点就不用到处写 0/1 比较。
  return path ~= nil and vim.fn.isdirectory(path) == 1
end

function M.is_file(path)
  return path ~= nil and vim.fn.filereadable(path) == 1
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

  local normalized = vim.fs.normalize(vim.fn.fnamemodify(expanded, ":p")):gsub("\\", "/")

  return trim_trailing_slash(normalized)
end

return M
