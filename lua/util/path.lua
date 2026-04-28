local M = {}

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

return M
