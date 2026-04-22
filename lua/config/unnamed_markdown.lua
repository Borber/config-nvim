local unnamed_markdown = vim.api.nvim_create_augroup("unnamed_markdown", { clear = true })

vim.api.nvim_create_autocmd("BufEnter", {
  group = unnamed_markdown,
  callback = function(event)
    -- Let startup screens initialize their own buffers before applying defaults.
    if vim.v.vim_did_enter == 0 then
      return
    end

    -- Only target ordinary unnamed buffers that don't already declare a filetype.
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
