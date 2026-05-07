-- ============================================
-- 项目 Session 管理
-- 自动保存/恢复 buffer 布局，按 cwd hash 隔离，
-- Home 目录使用 Starter 入口代替 session。
-- ============================================
local M = {}
local configured = false
local path_util = require("libs.path")
local project = require("plugins.mini.project")
local canonical_path = path_util.canonical

local function session_file()
  return require("plugins.mini.sessions.session_file")
end

local function project_basename(path)
  return path_util.basename(path) or "session"
end

local function session_slug(text)
  local slug = text:gsub("[^%w._-]", "-"):gsub("-+", "-"):gsub("^-", ""):gsub("-$", "")

  return slug ~= "" and slug or "session"
end

local function current_directory()
  return canonical_path(vim.fn.getcwd())
end

local function current_session_name()
  -- session 文件名同时包含项目目录名和 cwd hash，
  -- 避免多个同名项目目录互相覆盖。
  local cwd = current_directory()
  local name = session_slug(project_basename(cwd))
  local hash = vim.fn.sha256(cwd):sub(1, 8)

  return string.format("%s-%s.vim", name, hash)
end

local function current_session_disabled_message()
  -- home 目录作为 starter 的入口页，不写项目 session。
  -- 否则随手退出 Neovim 会把 home 也恢复成一个“项目”。
  return project.session_disabled_reason(current_directory())
end

local function current_session_path()
  local directory = require("mini.sessions").config.directory
  return canonical_path(vim.fs.joinpath(directory, current_session_name()))
end

local function delete_current_session(opts)
  -- 过滤后没有可恢复文件时，删除旧 session，避免下次又恢复到空壳状态。
  local path = current_session_path()
  if not path_util.exists(path) then
    return
  end

  local ok, result = pcall(vim.fn.delete, path)
  if ok and result == 0 and opts and opts.verbose then
    vim.notify("Removed empty session", vim.log.levels.INFO)
  elseif not ok or result ~= 0 then
    vim.notify("Failed to remove empty session: " .. path, vim.log.levels.ERROR)
  end
end

local function close_transient_windows()
  local minifiles = package.loaded["mini.files"]
  if minifiles ~= nil then
    minifiles.close()
  end
end

local function is_headless()
  return #vim.api.nvim_list_uis() == 0
end

local function startup_directory()
  if vim.fn.argc() ~= 1 then
    return nil
  end

  local argv0 = vim.fn.argv(0)
  if type(argv0) ~= "string" then
    return nil
  end

  local path = vim.fn.fnamemodify(argv0, ":p")
  if not path_util.is_directory(path) then
    return nil
  end

  return canonical_path(path)
end

local function notify_read_error(err)
  vim.notify(tostring(err), vim.log.levels.WARN)
end

function M.setup()
  if configured then
    return
  end

  configured = true

  -- session 只恢复真实文件 buffer；不保存 localoptions，
  -- 避免折叠、statusline、signcolumn 等窗口/缓冲区局部状态污染下次启动。
  vim.opt.sessionoptions = {
    "buffers",
  }

  require("mini.sessions").setup({
    autoread = false,
    autowrite = false,
    file = "",
    hooks = {
      pre = {
        read = close_transient_windows,
        write = close_transient_windows,
      },
    },
    verbose = {
      read = true,
      write = false,
      delete = true,
    },
  })

  local group = vim.api.nvim_create_augroup("ConfigMiniSessions", { clear = true })

  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    nested = true,
    once = true,
    callback = function()
      local directory = startup_directory()
      if directory ~= nil then
        vim.api.nvim_set_current_dir(directory)
        require("plugins.mini.sessions.buffers").mark_startup_directory_placeholder(directory)
      end

      if M.should_auto_restore() then
        M.read_current({ verbose = false })
      end
    end,
    desc = "Restore current project session",
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      if not is_headless() then
        M.write_current({ verbose = false })
      end
    end,
    desc = "Write current project session",
  })

  vim.api.nvim_create_user_command("SessionSave", function()
    M.write_current({ verbose = true })
  end, { desc = "Save current project session", force = true })

  vim.api.nvim_create_user_command("SessionRestore", function()
    M.read_current()
  end, { desc = "Restore current project session", force = true })

  vim.api.nvim_create_user_command("SessionSelect", function()
    M.select_read()
  end, { desc = "Select session to restore", force = true })

  vim.api.nvim_create_user_command("SessionDelete", function()
    M.select_delete()
  end, { desc = "Select session to delete", force = true })
end

function M.has_current()
  -- 只有 session 文件里确实有可恢复文件时才认为当前项目有 session。
  -- 空 session 会被顺手删除，避免下一次启动反复恢复到空壳。
  M.setup()

  if current_session_disabled_message() ~= nil then
    return false
  end

  local path = current_session_path()
  if session_file().has_meaningful_buffers(path) then
    return true
  end

  delete_current_session()
  return false
end

function M.should_auto_restore()
  -- headless 模式通常是测试或脚本调用，不自动读写 UI session。
  return not is_headless() and (vim.fn.argc() == 0 or startup_directory() ~= nil) and M.has_current()
end

function M.write_current(opts)
  -- 写入时先收集真实文件 buffer，再让 mini.sessions 生成原始 session，
  -- 最后由 session_file.sanitize 过滤掉目录/空白占位等无意义路径。
  M.setup()
  opts = opts or {}

  local disabled_message = current_session_disabled_message()
  if disabled_message ~= nil then
    if opts.verbose then
      vim.notify(disabled_message, vim.log.levels.INFO)
    end

    return
  end

  local session_buffers = require("plugins.mini.sessions.buffers")
  local paths, first_buf = session_buffers.meaningful_paths()
  if not session_buffers.has_meaningful_paths(paths) then
    -- 当前项目没有真实文件 buffer 时，旧 session 也一起清掉。
    delete_current_session(opts)

    if opts.verbose then
      vim.notify("No meaningful buffers to save in session", vim.log.levels.INFO)
    end

    return
  end

  local function write_session()
    require("mini.sessions").write(current_session_name(), {
      force = true,
      verbose = opts.verbose == true,
    })
  end

  local ok, err
  if first_buf ~= nil then
    -- 在真实文件 buffer 语境下写 session，减少空白/目录 buffer 影响。
    ok, err = pcall(vim.api.nvim_buf_call, first_buf, write_session)
  else
    ok, err = pcall(write_session)
  end

  if not ok then
    vim.notify("Failed to write session: " .. tostring(err), vim.log.levels.ERROR)
    return
  end

  if not session_file().sanitize(current_session_path(), paths) then
    delete_current_session(opts)
    vim.notify("Failed to sanitize current session", vim.log.levels.ERROR)
  end
end

function M.read_current(opts)
  -- 读取当前项目 session，但保留调用前 cwd。
  -- 旧 session 可能残留 :cd；读取后恢复用户选择的 cwd，避免 Starter Open 被旧项目污染。
  M.setup()
  opts = opts or {}
  local directory = current_directory()

  local disabled_message = current_session_disabled_message()
  if disabled_message ~= nil then
    if opts.notify ~= false then
      vim.notify(disabled_message, vim.log.levels.INFO)
    end

    return false
  end

  local ok, err = pcall(function()
    require("mini.sessions").read(current_session_name(), {
      force = false,
      verbose = opts.verbose ~= false,
    })
  end)

  local restore_ok, restore_err = pcall(vim.api.nvim_set_current_dir, directory)
  if not restore_ok and opts.notify ~= false then
    vim.notify("Failed to restore cwd after session read: " .. tostring(restore_err), vim.log.levels.ERROR)
  end

  if not ok and opts.notify ~= false then
    notify_read_error(err)
  end

  return ok
end

function M.select_read()
  M.setup()
  require("mini.sessions").select("read", { force = false, verbose = true })
end

function M.select_delete()
  M.setup()
  require("mini.sessions").select("delete", { force = false, verbose = true })
end

return M
