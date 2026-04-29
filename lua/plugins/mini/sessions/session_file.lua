local M = {}
local path_util = require("util.path")

function M.canonical_path(path)
  -- session 文件里的路径和 buffer 路径来源不同，统一后才能稳定比较。
  return path_util.canonical_absolute(path)
end

local function line_path(line)
  -- 只解析 :mksession 里会恢复/引用 buffer 路径的命令行。
  -- kind 区分“真正恢复 buffer 的行”和“仅作为引用的行”，过滤时要保留这个语义。
  local path = line:match("^badd%s+%+%-?%d+%s+(.+)$")
  if path ~= nil then
    return path, "badd"
  end

  path = line:match("^edit%s+(.+)$")
  if path ~= nil then
    return path, "edit"
  end

  path = line:match("^balt%s+(.+)$")
  if path ~= nil then
    return path, "reference"
  end

  path = line:match("^%$argadd%s+(.+)$") or line:match("^argadd%s+(.+)$")
  if path ~= nil then
    return path, "reference"
  end
end

local function is_readable_path(path)
  local normalized = M.canonical_path(path)
  if normalized == nil then
    return false
  end

  return path_util.is_file(normalized)
end

function M.has_meaningful_buffers(path)
  -- 旧 session 只有包含真实可读文件时才值得恢复。
  if vim.uv.fs_stat(path) == nil then
    return false
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end

  for _, line in ipairs(lines) do
    local session_path, kind = line_path(line)
    if (kind == "badd" or kind == "edit") and is_readable_path(session_path) then
      return true
    end
  end

  return false
end

local function insert_entrypoint_when_missing(lines, first_buffer_path)
  -- 有些 session 只剩 badd，没有 edit；恢复后会落到空窗口。
  -- 把入口文件插在最后一个 badd 后面，尽量贴近 mksession 原本的结构。
  local insert_at = 0
  for index, line in ipairs(lines) do
    if line:match("^badd%s+") then
      insert_at = index
    end
  end

  table.insert(lines, insert_at + 1, "edit " .. first_buffer_path)
end

function M.sanitize(path, meaningful_paths)
  -- mini.sessions 先生成完整 session，再二次过滤掉无意义路径。
  -- 保留非路径行，移除指向目录/空白占位/失效文件的 buffer 行。
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end

  local filtered = {}
  local has_buffer_line = false
  local has_edit_line = false
  local first_buffer_path

  for _, line in ipairs(lines) do
    local session_path, kind = line_path(line)

    if session_path == nil then
      table.insert(filtered, line)
    else
      local normalized_path = M.canonical_path(session_path)
      if normalized_path ~= nil and meaningful_paths[normalized_path] then
        table.insert(filtered, line)
        if kind == "badd" or kind == "edit" then
          has_buffer_line = true
          first_buffer_path = first_buffer_path or session_path
        end
        has_edit_line = has_edit_line or kind == "edit"
      end
    end
  end

  if not has_buffer_line then
    return false
  end

  if not has_edit_line and first_buffer_path ~= nil then
    -- 只有 badd 没有 edit 时，补一个入口文件，避免恢复后落到空窗口。
    insert_entrypoint_when_missing(filtered, first_buffer_path)
  end

  local write_ok, result = pcall(vim.fn.writefile, filtered, path)
  return write_ok and result == 0
end

return M
