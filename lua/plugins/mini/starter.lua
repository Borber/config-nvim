local M = {}
local configured = false
local buffer_util = require("libs.buffer")
local starter_refresh_after_lazy = false

local function current_recent_path()
  -- mini.starter 的一行内容由多个 unit 组成，需要从当前行里找出 Recent paths item。
  local content = require("mini.starter").get_content()
  if content == nil then
    return nil
  end

  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local content_line = content[cursor_line]

  if content_line == nil then
    return nil
  end

  for _, unit in ipairs(content_line) do
    if unit.type == "item" and unit.item ~= nil and unit.item.section == "Recent paths" then
      return unit.item.recent_path
    end
  end

  return nil
end

local function delete_current_recent_path()
  local recent_path = current_recent_path()
  if recent_path == nil then
    return
  end

  local visits = require("plugins.mini.visits")
  if visits.remove_recent_path(recent_path) then
    -- 删除后立即刷新启动页，不需要重开 Neovim。
    require("mini.starter").refresh()
  end
end

local function attach_starter_mappings(buf_id)
  vim.keymap.set("n", "<BS>", delete_current_recent_path, {
    buffer = buf_id,
    desc = "Delete recent path",
    silent = true,
  })
end

local function is_terminal_running(buf_id)
  -- 这里能可靠判断的是 terminal job 是否还活着；shell 是否“空闲”没有稳定通用信号。
  local ok, job_id = pcall(vim.api.nvim_buf_get_var, buf_id, "terminal_job_id")
  if not ok or type(job_id) ~= "number" then
    return false
  end

  return vim.fn.jobwait({ job_id }, 0)[1] == -1
end

local function is_clearable_buffer(buf_id)
  -- Starter 是项目切换入口：清掉用户可见 buffer，但保留仍在运行的 terminal。
  if buffer_util.resolve(buf_id) == nil then
    return false
  end

  if buffer_util.is_terminal(buf_id) then
    return not is_terminal_running(buf_id)
  end

  return vim.bo[buf_id].buflisted
end

local function save_buffer(buf_id)
  if not vim.bo[buf_id].modified or vim.bo[buf_id].readonly or not vim.bo[buf_id].modifiable then
    return
  end

  local ok, err = pcall(vim.api.nvim_buf_call, buf_id, function()
    vim.cmd("silent write")
  end)

  if not ok then
    vim.notify("Failed to save buffer before opening starter: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function delete_buffer(buf_id)
  save_buffer(buf_id)

  local bufremove = require("mini.bufremove")
  local ok, err = pcall(bufremove.delete, buf_id, false)
  if not ok then
    vim.notify("Failed to delete buffer before opening starter: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function hide_hidden_empty_placeholders()
  -- 当前窗口是 NeogitStatus 等特殊 buffer 时，mini.bufremove 清场可能造出隐藏的空 listed buffer。
  -- 它不该出现在顶栏里，但仍可留给后续 :edit 复用。
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local is_hidden_empty = vim.bo[buf_id].buflisted and #vim.fn.win_findbuf(buf_id) == 0 and buffer_util.is_empty_unnamed(buf_id)

    if is_hidden_empty then
      vim.bo[buf_id].buflisted = false
    end
  end
end

local function home_directory()
  return vim.uv.os_homedir() or vim.fn.expand("~")
end

local function startup_footer()
  local ok, stats = pcall(function()
    return require("lazy").stats()
  end)

  if not ok or type(stats) ~= "table" then
    return ""
  end

  local startuptime = stats.startuptime or 0
  starter_refresh_after_lazy = startuptime <= 0

  if startuptime <= 0 then
    return ("Loaded %d/%d plugins"):format(stats.loaded or 0, stats.count or 0)
  end

  local ms = math.floor(startuptime * 100 + 0.5) / 100
  return ("Loaded %d/%d plugins in %.2f ms"):format(stats.loaded or 0, stats.count or 0, ms)
end

local function refresh_starter_after_lazy()
  if not starter_refresh_after_lazy or vim.bo.filetype ~= "ministarter" then
    return
  end

  starter_refresh_after_lazy = false
  require("mini.starter").refresh()
end

local function prepare_starter()
  -- 真正进入 Starter 前先保存当前项目并清场，让下一次 Open 像刚启动一样干净。
  require("plugins.mini.sessions").write_current({ verbose = false })

  require("mini.files").close()

  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    if is_clearable_buffer(buf_id) then
      delete_buffer(buf_id)
    end
  end

  local ok, err = pcall(function()
    vim.cmd("silent only")
  end)
  if not ok then
    vim.notify("Failed to keep only starter window: " .. tostring(err), vim.log.levels.ERROR)
  end
  hide_hidden_empty_placeholders()
end

local function ensure_setup(autoopen)
  if configured then
    return
  end

  configured = true

  local starter = require("mini.starter")
  local visits = require("plugins.mini.visits")

  -- 最近路径的采集独立放在 visits 模块里，starter 这里只负责展示和动作。
  visits.setup()

  starter.setup({
    autoopen = autoopen == true,
    header = "",
    footer = startup_footer,
    items = {
      visits.recent_paths_section(5),
      {
        name = "Find file",
        action = function()
          require("telescope.builtin").find_files()
        end,
        section = "Actions",
      },
      {
        name = "New file",
        action = "ene | startinsert",
        section = "Actions",
      },
      {
        name = "Open",
        action = function()
          require("plugins.mini.files").open(home_directory())
        end,
        section = "Actions",
      },
      {
        name = "Config",
        action = function()
          require("plugins.mini.visits").open_path(vim.fn.stdpath("config"), { record = false })
        end,
        section = "Actions",
      },
      {
        name = "Quit",
        action = "qa",
        section = "Actions",
      },
    },
    content_hooks = {
      starter.gen_hook.aligning("center", "center"),
    },
    silent = true,
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("ConfigMiniStarterMappings", { clear = true }),
    pattern = "MiniStarterOpened",
    callback = function(args)
      attach_starter_mappings(args.buf ~= 0 and args.buf or vim.api.nvim_get_current_buf())
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("ConfigMiniStarterLazyStats", { clear = true }),
    pattern = "LazyVimStarted",
    callback = function()
      vim.schedule(refresh_starter_after_lazy)
    end,
  })
end

function M.setup(opts)
  opts = opts or {}
  ensure_setup(opts.autoopen)
end

function M.open()
  ensure_setup(false)
  prepare_starter()

  local starter_buf
  local buf_id = vim.api.nvim_get_current_buf()
  if buffer_util.is_empty_unnamed(buf_id) then
    starter_buf = buf_id
  end

  require("mini.starter").open(starter_buf)
end

return M
