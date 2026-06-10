-- ============================================
-- 配置生命周期
-- ============================================
local M = {}

local buffer_util = require("libs.buffer")
local state = require("state.lifecycle")

M.user_patterns = {
  ui_ready = "ConfigUiReady",
  file_post = "ConfigFilePost",
}

M.lazy_events = {
  ui_ready = "User ConfigUiReady",
  file_post = "User ConfigFilePost",
}

local configured = false

-- ============================================
-- 事件状态与广播
-- ============================================
local function synthetic_event(name)
  local data = state[name].data

  return {
    event = "User",
    match = M.user_patterns[name],
    buf = data and data.buf or 0,
    data = data,
  }
end

function M.ready(name)
  local target = state[name]
  if target == nil then
    error("Unknown lifecycle event: " .. tostring(name))
  end

  return target.fired
end

function M.emit(name, data)
  local pattern = M.user_patterns[name]
  if pattern == nil then
    error("Unknown lifecycle event: " .. tostring(name))
  end

  state[name].fired = true
  state[name].data = data

  vim.api.nvim_exec_autocmds("User", {
    pattern = pattern,
    modeline = false,
    data = data,
  })
end

function M.once(name, callback, opts)
  opts = opts or {}

  if M.ready(name) then
    local run = function()
      callback(synthetic_event(name))
    end

    if opts.schedule then
      vim.schedule(run)
    else
      run()
    end

    return
  end

  vim.api.nvim_create_autocmd("User", {
    group = opts.group,
    pattern = M.user_patterns[name],
    once = true,
    callback = callback,
    desc = opts.desc,
  })
end

function M.on(name, callback, opts)
  opts = opts or {}

  if M.ready(name) then
    local run = function()
      callback(synthetic_event(name))
    end

    if opts.schedule then
      vim.schedule(run)
    else
      run()
    end

    return
  end

  vim.api.nvim_create_autocmd("User", {
    group = opts.group,
    pattern = M.user_patterns[name],
    callback = callback,
    desc = opts.desc,
  })
end

-- ============================================
-- 生命周期自动命令
-- ============================================
local function setup_lazy_layers()
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("config_lazy_layers", { clear = true }),
    pattern = "VeryLazy",
    once = true,
    callback = function()
      M.emit("ui_ready")
    end,
    desc = "Emit ConfigUiReady after VeryLazy",
  })
end

local function setup_file_post()
  local group_name = "config_file_post"
  local file_post_fired = state.file_post.fired
  local ui_entered = false

  local function fire_file_post(bufnr)
    if file_post_fired or not ui_entered or not buffer_util.is_normal_file(bufnr) then
      return
    end

    file_post_fired = true
    M.emit("file_post", { buf = bufnr })
    vim.api.nvim_del_augroup_by_name(group_name)
  end

  vim.api.nvim_create_autocmd({ "UIEnter", "BufReadPost", "BufNewFile" }, {
    group = vim.api.nvim_create_augroup(group_name, { clear = true }),
    callback = function(event)
      if event.event == "UIEnter" then
        ui_entered = true
      end

      fire_file_post(event.buf)
    end,
    desc = "Emit ConfigFilePost after UI enters a real file buffer",
  })
end

function M.setup()
  if configured then
    return
  end

  configured = true
  setup_lazy_layers()
  setup_file_post()
end

return M
