-- ============================================
-- 全局 autocmd
-- ============================================
local augroup = vim.api.nvim_create_augroup

-- 让无名 buffer 默认以 markdown filetype 打开
vim.api.nvim_create_autocmd("BufEnter", {
  group = augroup("unnamed_markdown", { clear = true }),
  callback = function(event)
    -- 启动屏幕等先初始化自己的 buffer
    if vim.v.vim_did_enter == 0 then
      return
    end

    if vim.bo[event.buf].buftype ~= "" then
      return
    end
    if vim.api.nvim_buf_get_name(event.buf) ~= "" then
      return
    end
    if vim.bo[event.buf].filetype ~= "" then
      return
    end

    vim.bo[event.buf].filetype = "markdown"
  end,
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
})
