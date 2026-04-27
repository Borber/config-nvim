-- ============================================
-- 全局 autocmd
-- ============================================
local augroup = vim.api.nvim_create_augroup

require("util.main_file").setup()

local function writable_normal_buffer(bufnr)
  if not bufnr or bufnr == 0 or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_get_current_buf()
  end

  if not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  local bo = vim.bo[bufnr]
  if bo.buftype ~= "" or not bo.modifiable or bo.readonly then
    return nil
  end

  return bufnr, bo
end

local function strip_carriage_returns(bufnr)
  local target_bufnr, bo = writable_normal_buffer(bufnr)
  if target_bufnr == nil or bo.binary then
    return
  end

  local view = vim.fn.winsaveview()

  pcall(vim.api.nvim_buf_call, target_bufnr, function()
    vim.cmd([[silent! keepjumps keeppatterns %s/\r//ge]])
  end)

  vim.fn.winrestview(view)
end

-- 仅对“正常文件 buffer”执行自动保存：
-- - 必须是有效 buffer
-- - 不能是 terminal/help/quickfix 等特殊 buftype
-- - 必须可修改、非只读、且当前确实有未保存改动
-- - 必须已经有文件名，避免把无名临时 buffer 强行写盘
local function autosave_normal_buffer(bufnr)
  local target_bufnr, bo = writable_normal_buffer(bufnr)
  if target_bufnr == nil or not bo.modified then
    return
  end

  if vim.api.nvim_buf_get_name(target_bufnr) == "" then
    return
  end

  pcall(vim.api.nvim_buf_call, target_bufnr, function()
    -- 用 :update 而不是 :write：只有内容真的变更时才写盘。
    -- silent 避免在频繁切窗/失焦时打扰命令行区域。
    vim.cmd("silent update")
  end)
end

-- 严格 autosave：覆盖几类最常见的“离开当前编辑上下文”场景
-- - InsertLeave：退出插入模式时保存
-- - BufLeave：离开当前 buffer（含切到 terminal / 切 tab / 切别的文件）时保存
-- - FocusLost：Neovim / Neovide 失焦时保存
-- - VimLeavePre：退出前再尽量保存一次
vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "FocusLost", "VimLeavePre" }, {
  group = augroup("config_autosave", { clear = true }),
  callback = function(event)
    autosave_normal_buffer(event.buf)
  end,
  desc = "Autosave normal file buffers",
})

-- 清理混合换行/残留 CR 字符，避免行尾显示 ^M。
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePre" }, {
  group = augroup("config_strip_carriage_returns", { clear = true }),
  callback = function(event)
    strip_carriage_returns(event.buf)
  end,
  desc = "Strip stray carriage returns from file buffers",
})

-- 打开内置终端时关闭行号/sign 并立即进入插入模式
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup("config_term_open", { clear = true }),
  callback = function(event)
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.bo[event.buf].buflisted = false
    vim.cmd("startinsert")
  end,
  desc = "Prepare terminal buffers",
})
