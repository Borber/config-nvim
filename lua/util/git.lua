local M = {}

local uv = vim.uv
local buffer_util = require("util.buffer")
local path_util = require("util.path")

local function normalize_path(path)
  return path_util.local_normalized(path)
end

function M.dir_from_buffer(bufnr)
  -- Git 上下文只从真实文件 buffer 推导；Neogit/terminal/空白 buffer 交给调用方回退 cwd。
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

  local stat = uv.fs_stat(name)
  if stat and stat.type == "directory" then
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

  return vim.fs.normalize(root)
end

return M
