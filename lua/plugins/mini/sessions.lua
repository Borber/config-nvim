local M = {}
local configured = false

local function project_basename(path)
  local trimmed = path:gsub("[/\\]+$", "")
  local name = trimmed:match("([^/\\]+)$")

  return name ~= nil and name ~= "" and name or "session"
end

local function session_slug(text)
  local slug = text:gsub("[^%w._-]", "-"):gsub("-+", "-"):gsub("^-", ""):gsub("-$", "")

  return slug ~= "" and slug or "session"
end

local function current_directory()
  return vim.fs.normalize(vim.fn.getcwd())
end

local function current_session_name()
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
  if current_directory_is_home() then
    return "Home directory uses starter instead of a session"
  end
end

local function current_session_path()
  return vim.fs.normalize(vim.fs.joinpath(require("mini.sessions").config.directory, current_session_name()))
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
  elseif (not ok or result ~= 0) and opts and opts.verbose then
    vim.notify("Failed to remove empty session", vim.log.levels.WARN)
  end
end

local function canonical_path(path)
  -- session 文件里的路径和 buffer 路径来源不同，统一后才能稳定比较。
  if path == nil or path == "" then
    return nil
  end

  local expanded = vim.fn.expand(path)
  if expanded == "" then
    expanded = path
  end

  local normalized = vim.fs.normalize(vim.fn.fnamemodify(expanded, ":p")):gsub("\\", "/")
  if #normalized > 3 then
    normalized = normalized:gsub("/+$", "")
  end

  return normalized
end

local function session_line_path(line)
  -- 只解析 :mksession 里会恢复/引用 buffer 路径的命令行。
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

local function is_session_file_path(path)
  local normalized = canonical_path(path)
  if normalized == nil then
    return false
  end

  return vim.fn.filereadable(normalized) == 1
end

local function session_has_meaningful_buffers(path)
  -- 旧 session 只有包含真实可读文件时才值得恢复。
  if vim.uv.fs_stat(path) == nil then
    return false
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end

  for _, line in ipairs(lines) do
    local session_path, kind = session_line_path(line)
    if (kind == "badd" or kind == "edit") and is_session_file_path(session_path) then
      return true
    end
  end

  return false
end

local function is_blank_placeholder_buffer(buf_id)
  -- 无名空白 buffer 或尚未落盘的空文件占位，不应该写进项目 session。
  local name = vim.api.nvim_buf_get_name(buf_id)
  if name == "" then
    return true
  end

  if vim.fn.filereadable(name) == 1 or not vim.api.nvim_buf_is_loaded(buf_id) or vim.bo[buf_id].modified then
    return false
  end

  return vim.api.nvim_buf_line_count(buf_id) == 1
    and vim.api.nvim_buf_get_lines(buf_id, 0, 1, false)[1] == ""
end

local function is_meaningful_buffer(buf_id)
  -- session 只保存普通文件 buffer；目录、特殊 buffer、空白占位都跳过。
  if not vim.api.nvim_buf_is_valid(buf_id) or not vim.bo[buf_id].buflisted or vim.bo[buf_id].buftype ~= "" then
    return false
  end

  local name = vim.api.nvim_buf_get_name(buf_id)
  if name == "" or vim.fn.isdirectory(name) == 1 or is_blank_placeholder_buffer(buf_id) then
    return false
  end

  return true
end

local function meaningful_buffer_paths()
  local paths = {}
  local first_buf

  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if is_meaningful_buffer(buf_id) then
      local path = canonical_path(vim.api.nvim_buf_get_name(buf_id))
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

local function has_meaningful_paths(paths)
  return next(paths) ~= nil
end

local function sanitize_session_file(path, meaningful_paths)
  -- mini.sessions 先生成完整 session，再二次过滤掉无意义路径。
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end

  local filtered = {}
  local has_buffer_line = false
  local has_edit_line = false
  local first_buffer_path

  for _, line in ipairs(lines) do
    local session_path, kind = session_line_path(line)

    if session_path == nil then
      table.insert(filtered, line)
    else
      local normalized_path = canonical_path(session_path)
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
    local insert_at = 0
    for index, line in ipairs(filtered) do
      if line:match("^badd%s+") then
        insert_at = index
      end
    end
    table.insert(filtered, insert_at + 1, "edit " .. first_buffer_path)
  end

  local write_ok, result = pcall(vim.fn.writefile, filtered, path)
  return write_ok and result == 0
end

local function close_transient_windows()
  pcall(function()
    require("mini.files").close()
  end)
end

local function is_headless()
  return #vim.api.nvim_list_uis() == 0
end

local function startup_directory()
  if vim.fn.argc() ~= 1 then
    return nil
  end

  local path = vim.fn.fnamemodify(vim.fn.argv(0), ":p")
  if vim.fn.isdirectory(path) ~= 1 then
    return nil
  end

  return vim.fs.normalize(path)
end

local function is_empty_directory_buffer(buf_id, directory)
  if not vim.api.nvim_buf_is_valid(buf_id) or not vim.api.nvim_buf_is_loaded(buf_id) then
    return false
  end

  if vim.bo[buf_id].buftype ~= "" or vim.bo[buf_id].modified then
    return false
  end

  local name = vim.api.nvim_buf_get_name(buf_id)
  if name == "" or vim.fn.isdirectory(name) ~= 1 then
    return false
  end

  if canonical_path(name) ~= canonical_path(directory) then
    return false
  end

  return vim.api.nvim_buf_line_count(buf_id) == 1
    and vim.api.nvim_buf_get_lines(buf_id, 0, 1, false)[1] == ""
end

local function mark_startup_directory_buffer(directory)
  -- nvim <dir> 会先创建一个目录名的空 buffer；没有 session 时它会留在首屏。
  -- 把它标成临时占位：不显示在 buffer 列表里，被真实文件替换/隐藏时自动擦掉。
  local buf_id = vim.api.nvim_get_current_buf()
  if not is_empty_directory_buffer(buf_id, directory) then
    return
  end

  vim.bo[buf_id].buflisted = false
  vim.bo[buf_id].bufhidden = "wipe"
end

local function notify_read_error(err)
  local message = tostring(err)

  if message:find("is not a name for detected session", 1, true) then
    message = "No session saved for current directory yet"
  end

  vim.notify(message, vim.log.levels.WARN)
end

local function collect_neogit_status_windows()
  local windows = {}

  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local buf_id = vim.api.nvim_win_get_buf(win_id)

    if vim.bo[buf_id].filetype == "NeogitStatus" then
      table.insert(windows, {
        win_id = win_id,
        cwd = vim.api.nvim_win_call(win_id, vim.fn.getcwd),
      })
    end
  end

  return windows
end

local function refresh_neogit_status_windows()
  for _, window in ipairs(collect_neogit_status_windows()) do
    if vim.api.nvim_win_is_valid(window.win_id) then
      pcall(function()
        local git = require("util.git")
        local main_file = require("util.main_file")
        vim.api.nvim_set_current_win(window.win_id)

        local repo_cwd = git.root_from(window.cwd)
          or git.root_from_buffer(main_file.current_buf())
        if not repo_cwd then
          return
        end

        local opts = { cwd = repo_cwd, kind = "replace", no_expand = true }
        require("neogit").open(opts)
        require("util.neogit_loading").start(opts, window.win_id)
      end)
    end
  end
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
      post = {
        read = refresh_neogit_status_windows,
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
        mark_startup_directory_buffer(directory)
      end

      if M.should_auto_restore() then
        M.read_current({ notify = false, verbose = false })
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
  M.setup()

  if current_session_disabled_message() ~= nil then
    return false
  end

  local path = current_session_path()
  if session_has_meaningful_buffers(path) then
    return true
  end

  delete_current_session()
  return false
end

function M.should_auto_restore()
  return not is_headless() and (vim.fn.argc() == 0 or startup_directory() ~= nil) and M.has_current()
end

function M.write_current(opts)
  M.setup()
  opts = opts or {}

  local disabled_message = current_session_disabled_message()
  if disabled_message ~= nil then
    if opts.verbose then
      vim.notify(disabled_message, vim.log.levels.INFO)
    end

    return
  end

  local paths, first_buf = meaningful_buffer_paths()
  if not has_meaningful_paths(paths) then
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
    if opts.verbose then
      vim.notify(err, vim.log.levels.WARN)
    end

    return
  end

  if not sanitize_session_file(current_session_path(), paths) then
    delete_current_session(opts)
    if opts.verbose then
      vim.notify("No meaningful buffers to save in session", vim.log.levels.INFO)
    end
  end
end

function M.read_current(opts)
  M.setup()
  opts = opts or {}
  -- 旧 session 可能残留 :cd；读取后恢复用户选择的 cwd，避免 Starter Open 被旧项目污染。
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

  pcall(vim.api.nvim_set_current_dir, directory)

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
