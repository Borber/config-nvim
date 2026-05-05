-- ============================================
-- 最近项目管理
-- 记录用户进入过的项目目录，供 Starter 展示；
-- 文件级历史交给 Neovim 的 oldfiles / Telescope oldfiles。
-- ============================================
local M = {}
local configured = false

local path_util = require("libs.path")
local recent_projects = nil
local recent_projects_store = vim.fn.stdpath("data") .. "/starter-recent-paths.json"
local recent_projects_limit = 100
local canonical_path = path_util.canonical_absolute
local is_directory = path_util.is_directory
local path_exists = path_util.exists

local function home_directory()
  local home = vim.uv.os_homedir()
  if home == nil or home == "" then
    return nil
  end

  return canonical_path(home)
end

local function project_from_path(path, cache)
  local resolved_path = canonical_path(path)
  if resolved_path == nil or not path_exists(resolved_path, cache) then
    return nil
  end

  local project = resolved_path
  if not is_directory(resolved_path, cache) then
    project = canonical_path(vim.fn.fnamemodify(resolved_path, ":h"))
    if project == nil or not is_directory(project, cache) then
      return nil
    end
  end

  if project == home_directory() then
    return nil
  end

  return project
end

local function load_recent_projects()
  -- 旧文件里可能存过文件路径；读取时统一折叠成它所在的项目目录。
  if recent_projects ~= nil then
    return recent_projects
  end

  recent_projects = {}
  if not path_exists(recent_projects_store) then
    return recent_projects
  end

  local lines = vim.fn.readfile(recent_projects_store)
  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(decoded) ~= "table" then
    vim.notify("Recent projects store is invalid: " .. recent_projects_store, vim.log.levels.ERROR)
    return recent_projects
  end

  local stat_cache = {}
  local seen = {}
  for _, path in ipairs(decoded) do
    local project = type(path) == "string" and project_from_path(path, stat_cache) or nil
    if project ~= nil and not seen[project] then
      seen[project] = true
      table.insert(recent_projects, project)
    end
  end

  return recent_projects
end

local function write_recent_projects()
  if recent_projects == nil then
    return
  end

  local directory = vim.fs.dirname(recent_projects_store)
  if directory ~= nil then
    local mkdir_ok = pcall(vim.fn.mkdir, directory, "p")
    if not mkdir_ok then
      vim.notify("Failed to create recent projects directory: " .. directory, vim.log.levels.ERROR)
      return
    end
  end

  local write_ok, result = pcall(vim.fn.writefile, { vim.json.encode(recent_projects) }, recent_projects_store)
  if not write_ok or result ~= 0 then
    vim.notify("Failed to write recent projects: " .. recent_projects_store, vim.log.levels.ERROR)
  end
end

local function push_recent_project(path)
  local project = project_from_path(path)
  if project == nil then
    return
  end

  local projects = load_recent_projects()

  for index = #projects, 1, -1 do
    if projects[index] == project then
      table.remove(projects, index)
    end
  end

  table.insert(projects, 1, project)

  while #projects > recent_projects_limit do
    table.remove(projects)
  end

  write_recent_projects()
end

local function remove_recent_project(path)
  local project = project_from_path(path)
  if project == nil then
    return false
  end

  local projects = load_recent_projects()
  local removed = false

  for index = #projects, 1, -1 do
    if projects[index] == project then
      table.remove(projects, index)
      removed = true
    end
  end

  if removed then
    write_recent_projects()
  end

  return removed
end

local function record_current_project()
  push_recent_project(vim.fn.getcwd())
end

local function path_name(path)
  return path_util.basename(path) or path
end

local function close_current_starter()
  -- 从 Starter 的最近项目切换时，先关闭启动页，让后续窗口目标回到真实编辑区。
  local buf_id = vim.api.nvim_get_current_buf()
  if vim.bo[buf_id].filetype ~= "ministarter" then
    return
  end

  require("mini.starter").close(buf_id)
end

local function format_project_name(path)
  local icon = require("libs.icons").basic.dir
  return string.format("%s  %s  %s", path_name(path), path, icon)
end

function M.setup()
  if configured then
    return
  end

  configured = true

  local group = vim.api.nvim_create_augroup("ConfigRecentProjects", { clear = true })

  if vim.v.vim_did_enter == 1 then
    record_current_project()
  else
    vim.api.nvim_create_autocmd("VimEnter", {
      group = group,
      once = true,
      callback = record_current_project,
      desc = "Record startup project",
    })
  end
end

function M.record_path(path)
  push_recent_project(path)
end

function M.open_path(path, opts)
  -- starter/recent project 的统一入口：记录项目、切 cwd、恢复 session 或打开文件。
  opts = opts or {}

  local resolved_path = canonical_path(path)
  if resolved_path == nil then
    return
  end

  local project = project_from_path(resolved_path)
  if opts.record ~= false and project ~= nil then
    push_recent_project(project)
  end

  close_current_starter()

  if is_directory(resolved_path) then
    -- 打开目录前先切 cwd，让 Telescope、mini.files 等工具以该项目为上下文。
    vim.api.nvim_set_current_dir(resolved_path)

    local sessions = require("plugins.mini.sessions")
    if sessions.has_current() and sessions.read_current({ notify = false, verbose = false }) then
      return
    end

    -- 目录是项目上下文，不是文件 buffer；没有 session 时打开文件树，而不是 edit 目录本身。
    require("plugins.mini.files").open(resolved_path)
    return
  end

  local directory = canonical_path(vim.fn.fnamemodify(resolved_path, ":h"))
  if directory ~= nil then
    -- 打开文件前先切 cwd，让 Telescope、mini.files 等工具以该文件所在目录为上下文。
    vim.api.nvim_set_current_dir(directory)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(resolved_path))
end

function M.remove_recent_path(path)
  return remove_recent_project(path)
end

function M.recent_paths_section(limit)
  limit = limit or 5

  return function()
    local items = {}
    local stat_cache = {}
    for _, project in ipairs(load_recent_projects()) do
      if not is_directory(project, stat_cache) then
        goto continue
      end

      table.insert(items, {
        action = function()
          M.open_path(project)
        end,
        name = format_project_name(project),
        recent_path = project,
        section = "Recent projects",
      })

      if #items >= limit then
        break
      end

      ::continue::
    end

    if #items == 0 then
      return {
        {
          name = "There are no recent projects yet",
          action = "",
          section = "Recent projects",
        },
      }
    end

    return items
  end
end

return M
