-- ============================================
-- 全局 autocmd
-- ============================================
local augroup = vim.api.nvim_create_augroup
local buffer_util = require("libs.buffer")
local path_util = require("libs.path")
require("config.lifecycle").setup()

local cr_scan_limit = 5 * 1024 * 1024

local function buffer_size(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    local stat = path_util.stat(name)
    if stat ~= nil and stat.size ~= nil then
      return stat.size
    end
  end

  local ok, offset = pcall(vim.api.nvim_buf_get_offset, bufnr, vim.api.nvim_buf_line_count(bufnr))
  return ok and offset >= 0 and offset or nil
end

local function has_carriage_return(bufnr)
  local size = buffer_size(bufnr)
  if size ~= nil and size > cr_scan_limit then
    return false
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)
  for start = 0, line_count - 1, 512 do
    local finish = math.min(start + 512, line_count)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, start, finish, false)) do
      if line:find("\r", 1, true) ~= nil then
        return true
      end
    end
  end

  return false
end

local function strip_carriage_returns(bufnr)
  local target_bufnr = buffer_util.normal_writable(bufnr)
  if target_bufnr == nil then
    return
  end

  if vim.bo[target_bufnr].binary or not has_carriage_return(target_bufnr) then
    return
  end

  local view = vim.fn.winsaveview()

  vim.api.nvim_buf_call(target_bufnr, function()
    vim.cmd([[keepjumps keeppatterns %s/\r//ge]])
  end)

  vim.fn.winrestview(view)
end

-- 清理混合换行/残留 CR 字符，避免行尾显示 ^M。
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePre" }, {
  group = augroup("config_strip_carriage_returns", { clear = true }),
  callback = function(event)
    strip_carriage_returns(event.buf)
  end,
  desc = "Strip stray carriage returns from file buffers",
})

-- 终端现在只保留轻量兼容：打开时做最小窗口整理，不再为焦点切回单独维护模式状态。
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup("config_term_open", { clear = true }),
  callback = function(event)
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.bo[event.buf].buflisted = false
    vim.cmd("startinsert!")
  end,
  desc = "Prepare terminal buffer on open",
})
