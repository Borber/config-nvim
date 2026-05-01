local M = {}
local configured = false
local path_util = require("util.path")
local session_buffers = require("plugins.mini.sessions.buffers")
local session_file = require("plugins.mini.sessions.session_file")

local function project_basename(path)
  return path_util.basename(path) or "session"
end

local function session_slug(text)
  local slug = text:gsub("[^%w._-]", "-"):gsub("-+", "-"):gsub("^-", ""):gsub("-$", "")

  return slug ~= "" and slug or "session"
end

local function current_directory()
  return vim.fs.normalize(vim.fn.getcwd())
end

local function current_session_name()
  -- session 文件名同时包含项目目录名和 cwd hash，
  -- 避免多个同名项目目录互相覆盖。
  local cwd = current_directory()
  local name = session_slug(project_basename(cwd))
  local hash = vim.fn.sha256(cwd):sub(1, 8)

  return string.format("%s-%s.vim", name, hash)
end

local function current_directory_is_home()
  local home = vim.uv.os_homedir()
  if home == nil or home == "" then
    return false
  end

  return current_directory() == vim.fs.normalize(home)
end

local function current_session_disabled_message()
  -- home 目录作为 starter 的入口页，不写项目 session。
  -- 否则随手退出 Neovim 会把 home 也恢复成一个“项目”。
  if current_directory_is_home() then
    return "Home directory uses starter instead of a session"
  end
end

local function current_session_path()
  local directory = require("mini.sessions").config.directory
  return vim.fs.normalize(vim.fs.joinpath(directory, current_session_name()))
end

local function delete_current_session(opts)
  -- 过滤后没有可恢复文件时，删除旧 session，避免下次又恢复到空壳状态。
  local path = current_session_path()
  if vim.uv.fs_stat(path) == nil then
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
  require("mini.files").close()
end

local function is_headless()
  return #vim.api.nvim_list_uis() == 0
end

local function startup_directory()
  if vim.fn.argc() ~= 1 then
    return nil
  end

  local path = vim.fn.fnamemodify(vim.fn.argv(0), ":p")
  if not path_util.is_directory(path) then
    return nil
  end

  return vim.fs.normalize(path)
end

local function notify_read_error(err)
  local message = tostring(err)

  if message:find("is not a name for detected session", 1, true) then
    message = "No session saved for current directory yet"
  end

  vim.notify(message, vim.log.levels.WARN)
end

function M.setup()
  if configured then
    return
  end

  configured = true

  -- cwd 由当前选择的目录决定；session 只负责恢复 buffer，不再抢项目目录。
  vim.opt.sessionoptions = {
    "buffers",
    "folds",
    "help",
    "localoptions",
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
        session_buffers.mark_startup_directory_placeholder(directory)
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

  vim.keymap.set("n", "<leader>ss", function()
    M.write_current({ verbose = true })
  end, { desc = "Save session", silent = true })

  vim.keymap.set("n", "<leader>sr", function()
    M.read_current()
  end, { desc = "Restore session", silent = true })

  vim.keymap.set("n", "<leader>sR", function()
    M.select_read()
  end, { desc = "Select session", silent = true })

  vim.keymap.set("n", "<leader>sd", function()
    M.select_delete()
  end, { desc = "Delete session", silent = true })
end

function M.has_current()
  -- 只有 session 文件里确实有可恢复文件时才认为当前项目有 session。
  -- 空 session 会被顺手删除，避免下一次启动反复恢复到空壳。
  M.setup()

  if current_session_disabled_message() ~= nil then
    return false
  end

  local path = current_session_path()
  if session_file.has_meaningful_buffers(path) then
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

  if not session_file.sanitize(current_session_path(), paths) then
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
