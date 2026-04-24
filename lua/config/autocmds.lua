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
