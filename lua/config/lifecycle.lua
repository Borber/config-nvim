-- ============================================
-- 配置生命周期
-- ============================================
local M = {}

local buffer_util = require("libs.buffer")
local path_util = require("libs.path")
local configured = false
local file_post_event

local patterns = {
  ui_ready = "VeryLazy",
  file_post = "ConfigFilePost",
}

M.lazy_events = {
  ui_ready = "VeryLazy",
  file_post = "User ConfigFilePost",
}

-- ============================================
-- 一次性订阅与回放
-- ============================================
function M.once(name, callback, opts)
  opts = opts or {}
  local pattern = assert(patterns[name], "Unknown lifecycle event: " .. tostring(name))
  local event

  if name == "file_post" then
    event = file_post_event
  elseif vim.g.did_very_lazy then
    event = { event = "User", match = pattern, buf = 0 }
  end

  local function run(args)
    if opts.schedule then
      vim.schedule(function()
        callback(args)
      end)
    else
      callback(args)
    end
  end

  if event ~= nil then
    run(event)
    return
  end

  vim.api.nvim_create_autocmd("User", {
    group = opts.group,
    pattern = pattern,
    once = true,
    callback = run,
    desc = opts.desc,
  })
end

-- ============================================
-- 首个文件就绪
-- ============================================
function M.setup()
  if configured then
    return
  end

  configured = true
  local group = vim.api.nvim_create_augroup("config_file_post", { clear = true })
  local ui_entered = vim.v.vim_did_enter == 1 and #vim.api.nvim_list_uis() > 0

  local function fire_file_post(bufnr)
    bufnr = buffer_util.resolve(bufnr)
    if file_post_event ~= nil or not ui_entered or bufnr == nil or not buffer_util.is_normal_file(bufnr) then
      return
    end

    local path = path_util.local_normalized(vim.api.nvim_buf_get_name(bufnr))
    if path == nil or path_util.is_directory(path) then
      return
    end

    file_post_event = { event = "User", match = patterns.file_post, buf = bufnr, data = { buf = bufnr } }
    vim.api.nvim_del_augroup_by_id(group)
    vim.api.nvim_exec_autocmds("User", {
      pattern = patterns.file_post,
      modeline = false,
      data = file_post_event.data,
    })
  end

  vim.api.nvim_create_autocmd({ "UIEnter", "BufReadPost", "BufNewFile", "BufEnter" }, {
    group = group,
    callback = function(event)
      if event.event == "UIEnter" then
        ui_entered = true
      end

      fire_file_post(event.buf)
    end,
    desc = "Emit ConfigFilePost after UI enters a real file buffer",
  })

  if ui_entered then
    fire_file_post(vim.api.nvim_get_current_buf())
  end
end

return M
