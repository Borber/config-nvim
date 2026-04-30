local M = {}
local buffer_util = require("util.buffer")

-- 记录最近进入过的普通文件 buffer，供 Neogit、状态栏等特殊 buffer 场景回退使用。
local last_file_bufnr

local function is_floating_win(win)
  -- 浮窗通常是 hover/picker/提示，不应改变“最近真实文件”的上下文。
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end

  return vim.api.nvim_win_get_config(win).relative ~= ""
end

local function redraw()
  -- 文件上下文会影响 lualine/tabline；延后刷新可避开窗口事件连发时的抖动。
  vim.schedule(function()
    pcall(vim.cmd, "redrawtabline")
    pcall(vim.cmd, "redrawstatus")
  end)
end

function M.is_normal_file(bufnr)
  if not bufnr or bufnr == 0 then
    return false
  end

  return buffer_util.is_normal_file(bufnr)
end

function M.track_current()
  local win = vim.api.nvim_get_current_win()
  if is_floating_win(win) then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not M.is_normal_file(bufnr) then
    return
  end

  last_file_bufnr = bufnr
  redraw()
end

function M.current_buf()
  local bufnr = vim.api.nvim_get_current_buf()
  if M.is_normal_file(bufnr) then
    return bufnr
  end

  -- 当前窗口不是普通文件时，沿用最近文件作为项目上下文来源。
  if M.is_normal_file(last_file_bufnr) then
    return last_file_bufnr
  end
end

function M.name(bufnr, opts)
  opts = opts or {}
  bufnr = bufnr or M.current_buf()

  if not M.is_normal_file(bufnr) then
    return "[No File]"
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if opts.path == 2 then
    return vim.fn.fnamemodify(name, ":p")
  end

  if opts.path == 1 then
    return vim.fn.fnamemodify(name, ":.")
  end

  return vim.fn.fnamemodify(name, ":t")
end

function M.status_name()
  local bufnr = M.current_buf()
  local name = M.name(bufnr, { path = 1 })

  if M.is_normal_file(bufnr) then
    if vim.bo[bufnr].readonly then
      name = name .. " [RO]"
    end

    if vim.bo[bufnr].modified then
      name = name .. " [+]"
    end
  end

  return name
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config_main_file", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter" }, {
    group = group,
    callback = M.track_current,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "WinClosed" }, {
    group = group,
    callback = function()
      -- 最近文件被删或窗口关闭后清空缓存，避免特殊 buffer 继续引用失效 bufnr。
      if not M.is_normal_file(last_file_bufnr) then
        last_file_bufnr = nil
      end

      redraw()
    end,
  })

  M.track_current()
end

return M
