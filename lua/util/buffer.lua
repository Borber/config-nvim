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

return M
