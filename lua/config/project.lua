-- ============================================
-- 项目工作流策略
-- ============================================
local M = {}

local path_util = require("libs.path")

M.recent_projects_store = vim.fn.stdpath("data") .. "/starter-recent-paths.json"
M.recent_projects_store_limit = 100
M.recent_paths_limit = 10

-- ============================================
-- Home 与项目识别
-- ============================================
function M.home_directory()
  local home = vim.uv.os_homedir()
  if home == nil or home == "" then
    return nil
  end

  return path_util.canonical_absolute(home)
end

function M.is_home_directory(path)
  local home = M.home_directory()
  local normalized = path_util.canonical_absolute(path)

  return home ~= nil and normalized ~= nil and normalized == home
end

function M.project_from_path(path, cache)
  local resolved_path = path_util.canonical_absolute(path)
  if resolved_path == nil or not path_util.exists(resolved_path, cache) then
    return nil
  end

  local project = resolved_path
  if not path_util.is_directory(resolved_path, cache) then
    project = path_util.canonical_absolute(vim.fn.fnamemodify(resolved_path, ":h"))
    if project == nil or not path_util.is_directory(project, cache) then
      return nil
    end
  end

  if M.is_home_directory(project) then
    return nil
  end

  return project
end

-- ============================================
-- Session 规则
-- ============================================
function M.session_disabled_reason(path)
  if M.is_home_directory(path) then
    return "Home directory uses starter instead of a session"
  end
end

return M
