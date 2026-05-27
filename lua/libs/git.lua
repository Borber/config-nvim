-- ============================================
-- Git 上下文推导工具
-- 从 buffer/目录推导 git root，供 Git UI/Gitsigns 等使用。
-- ============================================
local M = {}

local buffer_util = require("libs.buffer")
local path_util = require("libs.path")
local normalize_path = path_util.local_normalized

function M.dir_from_buffer(bufnr)
  -- Git 上下文只从真实文件 buffer 推导；terminal/空白 buffer 交给调用方回退 cwd。
  if bufnr == nil then
    return nil
  end

  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not buffer_util.is_normal_file(bufnr) then
    return nil
  end

  local name = normalize_path(vim.api.nvim_buf_get_name(bufnr))
  if not name then
    return nil
  end

  if path_util.is_directory(name) then
    return name
  end

  return vim.fs.dirname(name)
end

function M.root_from(dir)
  -- 交给 git 自己解析 worktree/symlink/submodule，比手写向上查找 .git 更稳。
  dir = normalize_path(dir)
  if not dir then
    return nil
  end

  local result = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end

  local root = vim.trim(result.stdout)
  if root == "" then
    return nil
  end

  return path_util.canonical(root)
end

function M.root_from_buffer_or_cwd(bufnr)
  local cwd = vim.fn.getcwd()
  local dir = M.dir_from_buffer(bufnr or 0) or cwd

  return M.root_from(dir) or M.root_from(cwd) or cwd
end

return M
