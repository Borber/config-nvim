local M = {}
local configured = false

local uv = vim.uv or vim.loop
local recent_paths = nil
local recent_paths_store = vim.fn.stdpath("data") .. "/starter-recent-paths.json"
local recent_paths_limit = 100

local function normalize_path(path)
  -- 转成绝对路径，避免同一个目录因为相对路径不同而在最近列表里重复出现。
  if path == nil or path == "" then
    return nil
  end

  return vim.fn.fnamemodify(path, ":p")
end

local function is_directory(path)
  return path ~= nil and vim.fn.isdirectory(path) == 1
end

local function path_directory(path)
  if path == nil then
    return nil
  end

  if is_directory(path) then
    return path
  end

  return normalize_path(vim.fn.fnamemodify(path, ":h"))
end

local function load_recent_paths()
  -- 最近路径按需懒加载，并缓存在内存里，避免 starter 每次刷新都读文件。
  if recent_paths ~= nil then
    return recent_paths
  end

  if uv.fs_stat(recent_paths_store) == nil then
    recent_paths = {}
    return recent_paths
  end

  local lines = vim.fn.readfile(recent_paths_store)
  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))

  recent_paths = {}
  if not ok or type(decoded) ~= "table" then
    return recent_paths
  end

  -- 读取时顺手过滤已经不存在的路径，starter 里就不会出现失效入口。
  for _, path in ipairs(decoded) do
    local resolved_path = normalize_path(path)
    if resolved_path ~= nil and uv.fs_stat(resolved_path) ~= nil then
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

local function push_recent_path(path)
  local resolved_path = normalize_path(path)
  if resolved_path == nil or uv.fs_stat(resolved_path) == nil then
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

  write_recent_paths()
end

local function remove_recent_path(path)
  local resolved_path = normalize_path(path)
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
    write_recent_paths()
  end

  return removed
end

local function startup_paths()
  local paths = {}

  -- argv 从后往前压入，最后显示时仍能保持命令行参数的原始顺序。
  for index = vim.fn.argc() - 1, 0, -1 do
    local resolved_path = normalize_path(vim.fn.argv(index))
    if resolved_path ~= nil and uv.fs_stat(resolved_path) ~= nil then
      table.insert(paths, resolved_path)
    end
  end

  return paths
end

local function path_name(path)
  local trimmed_path = path:gsub("[/\\]+$", "")
  local name = trimmed_path:match("([^/\\]+)$")

  return name or path
end

local function format_path_name(path)
  local icon = is_directory(path) and "󰉋" or "󰈔"
  local name = path_name(path)

  return string.format("%s  %s  %s", name, path, icon)
end

function M.setup()
  if configured then
    return
  end

  configured = true

  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("ConfigStarterRecentPaths", { clear = true }),
    once = true,
    callback = function()
      for _, path in ipairs(startup_paths()) do
        push_recent_path(path)
      end
    end,
  })
end

function M.record_path(path)
  local resolved_path = normalize_path(path)
  if resolved_path == nil then
    return
  end

  push_recent_path(resolved_path)
end

function M.open_path(path, opts)
  opts = opts or {}

  local resolved_path = normalize_path(path)
  if resolved_path == nil then
    return
  end

  if opts.record ~= false then
    M.record_path(resolved_path)
  end

  local directory = path_directory(resolved_path)
  if directory ~= nil then
    -- 打开文件/目录前先切 cwd，让 Telescope、mini.files 等工具以该项目为上下文。
    vim.api.nvim_set_current_dir(directory)
  end

  if is_directory(resolved_path) then
    local sessions = require("plugins.mini.sessions")
    if sessions.has_current() and sessions.read_current({ notify = false, verbose = false }) then
      return
    end
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
    for _, path in ipairs(load_recent_paths()) do
      if uv.fs_stat(path) == nil then
        goto continue
      end

      table.insert(items, {
        action = function()
          M.open_path(path)
        end,
        name = format_path_name(path),
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
