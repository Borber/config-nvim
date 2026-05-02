local M = {}
local path_util = require("util.path")

-- 把传入的 bufnr 规整成一个有效的 buffer 编号，0 / nil 视为当前 buffer。
local function resolve_bufnr(bufnr)
  if not bufnr or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  return bufnr
end

function M.resolve(bufnr)
  return resolve_bufnr(bufnr)
end

-- 判断 buffer 是否为“可写的普通文件 buffer”：
-- 必须有效、非特殊 buftype（terminal/help/quickfix 等）、可修改且非只读。
-- 返回 (bufnr, bo) 方便调用方继续读其它 buffer 选项；不是则返回 nil。
function M.normal_writable(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return nil
  end

  local bo = vim.bo[bufnr]
  if bo.buftype ~= "" or not bo.modifiable or bo.readonly then
    return nil
  end

  return bufnr, bo
end

function M.normal_writable_file(bufnr)
  -- autosave 等写盘动作要求已经有文件名；无名 scratch buffer 不应该被 :write。
  local target_bufnr, bo = M.normal_writable(bufnr)
  if target_bufnr == nil or vim.api.nvim_buf_get_name(target_bufnr) == "" then
    return nil
  end

  return target_bufnr, bo
end

function M.is_normal_file(bufnr)
  -- 普通文件上下文：非特殊 buftype，且已经关联一个文件名。
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return false
  end

  return vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

function M.is_listed_normal_file(bufnr)
  -- session 只关心用户可见的普通文件 buffer；未列出的临时 buffer 不写入会话。
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return false
  end

  return vim.bo[bufnr].buflisted
    and vim.bo[bufnr].buftype == ""
    and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

function M.is_terminal(bufnr)
  -- starter 清场时终端有特殊规则：运行中的 terminal 要保留。
  bufnr = resolve_bufnr(bufnr)
  return bufnr ~= nil and vim.bo[bufnr].buftype == "terminal"
end

function M.is_empty_unnamed(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil or not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end

  if vim.api.nvim_buf_get_name(bufnr) ~= "" or vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].modified then
    return false
  end

  return vim.api.nvim_buf_line_count(bufnr) == 1
    and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
end

function M.is_directory_placeholder(bufnr, directory)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil or not vim.api.nvim_buf_is_loaded(bufnr) then
    return false
  end

  if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].modified then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or not path_util.is_directory(name) then
    return false
  end

  if directory ~= nil then
    local canonical = path_util.canonical_absolute
    if canonical(name) ~= canonical(directory) then
      return false
    end

    return vim.api.nvim_buf_line_count(bufnr) == 1
      and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
  end

  return true
end

function M.is_blank_placeholder(bufnr)
  -- 区分“尚未落盘的空占位”和真实文件：前者不应该进入 session/buffer 列表。
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return true
  end

  if path_util.is_file(name) or not vim.api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].modified then
    return false
  end

  return vim.api.nvim_buf_line_count(bufnr) == 1
    and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
end

function M.window_has_reusable_placeholder(win_id)
  if win_id == nil or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(win_id)
  return M.is_empty_unnamed(bufnr) or M.is_directory_placeholder(bufnr)
end

return M
