local M = {}

function M.is_uri(path)
  return type(path) == "string" and path:match("^%w[%w+.-]*://") ~= nil
end

-- Windows/Unix 路径统一成 /，并去掉多余尾斜杠，方便后续前缀比较。
function M.canonical(path)
  if path == nil or path == "" then
    return path
  end

  local normalized = vim.fs.normalize(path):gsub("\\", "/")
  normalized = normalized:gsub("^([A-Za-z]:)/+", "%1/")

  if #normalized > 3 then
    normalized = normalized:gsub("/+$", "")
  end

  return normalized
end

function M.local_normalized(path)
  if not path or path == "" or M.is_uri(path) then
    return nil
  end

  return vim.fs.normalize(path)
end

function M.absolute(path)
  if path == nil or path == "" then
    return nil
  end

  return vim.fn.fnamemodify(path, ":p")
end

function M.canonical_absolute(path)
  if path == nil or path == "" then
    return nil
  end

  local expanded = vim.fn.expand(path)
  if expanded == "" then
    expanded = path
  end

  local normalized = vim.fs.normalize(vim.fn.fnamemodify(expanded, ":p")):gsub("\\", "/")
  if #normalized > 3 then
    normalized = normalized:gsub("/+$", "")
  end

  return normalized
end

return M
