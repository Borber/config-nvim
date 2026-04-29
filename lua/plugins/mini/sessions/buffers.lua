local M = {}
local buffer_util = require("util.buffer")
local path_util = require("util.path")
local session_file = require("plugins.mini.sessions.session_file")

local function is_meaningful(buf_id)
  -- session 只保存普通文件 buffer；目录、特殊 buffer、空白占位都跳过。
  -- 这里不检查文件是否存在，存在性由 session_file.sanitize 统一处理。
  if not buffer_util.is_listed_normal_file(buf_id) then
    return false
  end

  local name = vim.api.nvim_buf_get_name(buf_id)
  if path_util.is_directory(name) or buffer_util.is_blank_placeholder(buf_id) then
    return false
  end

  return true
end

function M.meaningful_paths()
  -- 返回 path set 给 session 文件过滤使用，同时返回第一个已加载文件 buffer。
  -- 写 session 时切到这个 buffer 的语境，可以减少空白/目录 buffer 对 mksession 的干扰。
  local paths = {}
  local first_buf

  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if is_meaningful(buf_id) then
      local path = session_file.canonical_path(vim.api.nvim_buf_get_name(buf_id))
      if path ~= nil then
        paths[path] = true
        if first_buf == nil and vim.api.nvim_buf_is_loaded(buf_id) then
          first_buf = buf_id
        end
      end
    end
  end

  return paths, first_buf
end

function M.has_meaningful_paths(paths)
  return next(paths) ~= nil
end

function M.mark_startup_directory_placeholder(directory)
  -- nvim <dir> 会先创建一个目录名的空 buffer；没有 session 时它会留在首屏。
  -- 把它标成临时占位：不显示在 buffer 列表里，被真实文件替换/隐藏时自动擦掉。
  local buf_id = vim.api.nvim_get_current_buf()
  if not buffer_util.is_directory_placeholder(buf_id, directory) then
    return
  end

  vim.bo[buf_id].buflisted = false
  vim.bo[buf_id].bufhidden = "wipe"
end

return M
