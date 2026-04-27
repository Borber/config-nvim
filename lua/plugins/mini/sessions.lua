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

local function session_has_file_buffers(path)
  if vim.uv.fs_stat(path) == nil then
    return false
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return false
  end

  for _, line in ipairs(lines) do
    if line:match("^badd%s+") or line:match("^edit%s+") then
      return true
    end
  end

  return false
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

local function has_file_buffer()
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf_id)
      and vim.bo[buf_id].buflisted
      and vim.bo[buf_id].buftype == ""
      and vim.api.nvim_buf_get_name(buf_id) ~= "" then
      return true
    end
  end

  return false
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

  for _, tab_id in ipairs(vim.api.nvim_list_tabpages()) do
    for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(tab_id)) do
      local buf_id = vim.api.nvim_win_get_buf(win_id)

      if vim.bo[buf_id].filetype == "NeogitStatus" then
        table.insert(windows, {
          tab_id = tab_id,
          win_id = win_id,
          cwd = vim.api.nvim_win_call(win_id, vim.fn.getcwd),
        })
      end
    end
  end

  return windows
end

local function refresh_neogit_status_windows()
  for _, window in ipairs(collect_neogit_status_windows()) do
    if vim.api.nvim_tabpage_is_valid(window.tab_id) and vim.api.nvim_win_is_valid(window.win_id) then
      pcall(function()
        local git = require("util.git")
        local repo_cwd = git.root_from_tab_file(window.tab_id) or git.root_from(window.cwd)
        if not repo_cwd then
          return
        end

        vim.api.nvim_set_current_tabpage(window.tab_id)
        vim.api.nvim_set_current_win(window.win_id)

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

  vim.opt.sessionoptions = {
    "blank",
    "buffers",
    "curdir",
    "folds",
    "help",
    "tabpages",
    "winsize",
    "winpos",
    "localoptions",
  }

  require("mini.sessions").setup({
    autoread = false,
    autowrite = true,
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

  return session_has_file_buffers(current_session_path())
end

function M.should_auto_restore()
  return not is_headless() and (vim.fn.argc() == 0 or startup_directory() ~= nil) and M.has_current()
end

function M.write_current(opts)
  M.setup()

  local disabled_message = current_session_disabled_message()
  if disabled_message ~= nil then
    if opts and opts.verbose then
      vim.notify(disabled_message, vim.log.levels.INFO)
    end

    return
  end

  if not has_file_buffer() then
    if opts and opts.verbose then
      vim.notify("No file buffers to save in session", vim.log.levels.INFO)
    end

    return
  end

  local ok, err = pcall(function()
    require("mini.sessions").write(current_session_name(), {
      force = true,
      verbose = opts and opts.verbose == true,
    })
  end)

  if not ok and opts and opts.verbose then
    vim.notify(err, vim.log.levels.WARN)
  end
end

function M.read_current(opts)
  M.setup()
  opts = opts or {}

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
