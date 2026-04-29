local M = {}

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

function M.is_normal_file(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return false
  end

  return vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_get_name(bufnr) ~= ""
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
  if name == "" or vim.fn.isdirectory(name) ~= 1 then
    return false
  end

  if directory ~= nil then
    local canonical = require("util.path").canonical_absolute
    if canonical(name) ~= canonical(directory) then
      return false
    end

    return vim.api.nvim_buf_line_count(bufnr) == 1
      and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
  end

  return true
end

function M.is_blank_placeholder(bufnr)
  bufnr = resolve_bufnr(bufnr)
  if bufnr == nil then
    return false
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return true
  end

  if vim.fn.filereadable(name) == 1 or not vim.api.nvim_buf_is_loaded(bufnr) or vim.bo[bufnr].modified then
    return false
  end

  return vim.api.nvim_buf_line_count(bufnr) == 1
    and vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] == ""
end

local function win_bufnr(win_id)
  if win_id == nil or not vim.api.nvim_win_is_valid(win_id) then
    return nil
  end

  return vim.api.nvim_win_get_buf(win_id)
end

function M.window_has_empty_unnamed(win_id)
  local bufnr = win_bufnr(win_id)
  return bufnr ~= nil and M.is_empty_unnamed(bufnr)
end

function M.window_has_directory_placeholder(win_id)
  local bufnr = win_bufnr(win_id)
  return bufnr ~= nil and M.is_directory_placeholder(bufnr)
end

function M.window_has_reusable_placeholder(win_id)
  return M.window_has_empty_unnamed(win_id) or M.window_has_directory_placeholder(win_id)
end

return M
