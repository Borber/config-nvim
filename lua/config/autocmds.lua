-- ============================================
-- 全局 autocmd
-- ============================================
local augroup = vim.api.nvim_create_augroup
local buffer_util = require("libs.buffer")
require("config.lifecycle").setup()

local function strip_carriage_returns(bufnr)
  local target_bufnr = buffer_util.normal_writable(bufnr)
  if target_bufnr == nil then
    return
  end

  if vim.bo[target_bufnr].binary then
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
