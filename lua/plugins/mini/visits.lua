-- ============================================
-- 最近路径管理
-- 记录用户打开过的文件/目录路径，供 Starter 展示，
-- 同时提供 open_path 统一入口（切 cwd → 恢复 session）。
-- ============================================
local M = {}
local configured = false

local path_util = require("libs.path")
local recent_paths = nil
local recent_paths_store = vim.fn.stdpath("data") .. "/starter-recent-paths.json"
local recent_paths_limit = 100
local startup_paths_recorded = false
local canonical_path = path_util.canonical_absolute
local is_directory = path_util.is_directory
local path_exists = path_util.exists

local function load_recent_paths()
  -- 最近路径按需懒加载，并缓存在内存里，避免 starter 每次刷新都读文件。
  if recent_paths ~= nil then
    return recent_paths
  end

  if not path_exists(recent_paths_store) then
    recent_paths = {}
    return recent_paths
  end

  local lines = vim.fn.readfile(recent_paths_store)
  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))

  recent_paths = {}
  if not ok or type(decoded) ~= "table" then
    vim.notify("Recent paths store is invalid: " .. recent_paths_store, vim.log.levels.ERROR)
    return recent_paths
  end

  -- 读取时顺手过滤已经不存在的路径，starter 里就不会出现失效入口。
  local stat_cache = {}
  for _, path in ipairs(decoded) do
    local resolved_path = canonical_path(path)
    if resolved_path ~= nil and path_exists(resolved_path, stat_cache) then
      table.insert(recent_paths, resolved_path)
    end
  end

  return recent_paths
end

local function write_recent_paths()
  if recent_paths == nil then
    return
  end

  vim.fn.writefile({ vim.json.encode(recent_paths) }, recent_paths_store)
end

-- 延迟写入：聚合短时间内的多次路径变更，避免频繁磁盘 IO。
local write_timer = nil
local function schedule_write()
  if write_timer then
    write_timer:stop()
  end
  write_timer = vim.defer_fn(write_recent_paths, 1000)
end

local function push_recent_path(path)
  local resolved_path = canonical_path(path)
  if resolved_path == nil or not path_exists(resolved_path) then
    return
  end

  local paths = load_recent_paths()

  -- 移到队首前先删除旧位置，保持“最近使用”列表唯一且有序。
  for index = #paths, 1, -1 do
    if paths[index] == resolved_path then
      table.remove(paths, index)
    end
  end

  table.insert(paths, 1, resolved_path)

  while #paths > recent_paths_limit do
    table.remove(paths)
  end

  schedule_write()
end

local function remove_recent_path(path)
  -- 删除最近路径时同样先规整成绝对路径，保证 UI 中展示的路径能命中存储项。
  local resolved_path = canonical_path(path)
  if resolved_path == nil then
    return false
  end

  local paths = load_recent_paths()
  local removed = false

  for index = #paths, 1, -1 do
    if paths[index] == resolved_path then
      table.remove(paths, index)
      removed = true
    end
  end

  if removed then
    schedule_write()
  end

  return removed
end

local function startup_paths()
  local paths = {}

  -- argv 从后往前压入，最后显示时仍能保持命令行参数的原始顺序。
  local stat_cache = {}
  for index = vim.fn.argc() - 1, 0, -1 do
    local resolved_path = canonical_path(vim.fn.argv(index))
    if resolved_path ~= nil and path_exists(resolved_path, stat_cache) then
      table.insert(paths, resolved_path)
    end
  end

  return paths
end

local function record_startup_paths()
  if startup_paths_recorded then
    return
  end

  startup_paths_recorded = true

  for _, path in ipairs(startup_paths()) do
    push_recent_path(path)
  end
end

local function path_name(path)
  return path_util.basename(path) or path
end

local function close_current_starter()
  -- 从 Starter 的最近路径或 <S-CR> 切换项目时，先关闭启动页，让后续窗口目标回到真实编辑区。
  local buf_id = vim.api.nvim_get_current_buf()
  if vim.bo[buf_id].filetype ~= "ministarter" then
    return
  end

  require("mini.starter").close(buf_id)
end

local function format_path_name(path, cache)
  local ic = require("libs.icons")
  local icon = path_util.is_directory(path, cache) and ic.basic.dir or ic.basic.file
  local name = path_name(path)

  return string.format("%s  %s  %s", name, path, icon)
end

function M.setup()
  if configured then
    return
  end

  configured = true

  if vim.v.vim_did_enter == 1 then
    vim.schedule(record_startup_paths)
    return
  end

  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("ConfigStarterRecentPaths", { clear = true }),
    once = true,
    callback = record_startup_paths,
  })

  -- 退出前立即刷盘，防止 timer 还没触发就关闭了 Neovim。
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("ConfigRecentPathsFlush", { clear = true }),
    callback = function()
      if write_timer then
        write_timer:stop()
        write_timer = nil
      end
      write_recent_paths()
    end,
  })
end

function M.record_path(path)
  push_recent_path(path)
end

function M.open_path(path, opts)
  -- starter/recent path 的统一入口：负责记录最近路径、切 cwd、恢复 session 或打开文件。
  opts = opts or {}

  local resolved_path = canonical_path(path)
  if resolved_path == nil then
    return
  end

  if opts.record ~= false then
    push_recent_path(resolved_path)
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
    -- 打开文件前先切 cwd，让 Telescope、mini.files 等工具以该项目为上下文。
    vim.api.nvim_set_current_dir(directory)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(resolved_path))
end

function M.remove_recent_path(path)
  return remove_recent_path(path)
end

function M.recent_paths_section(limit)
  limit = limit or 5

  return function()
    local items = {}
    local stat_cache = {}
    for _, path in ipairs(load_recent_paths()) do
      if not path_exists(path, stat_cache) then
        goto continue
      end

      table.insert(items, {
        action = function()
          M.open_path(path)
        end,
        name = format_path_name(path, stat_cache),
        recent_path = path,
        section = "Recent paths",
      })

      if #items >= limit then
        break
      end

      ::continue::
    end

    if #items == 0 then
      return {
        {
          name = "There are no recent paths yet",
          action = "",
          section = "Recent paths",
        },
      }
    end

    return items
  end
end

return M
