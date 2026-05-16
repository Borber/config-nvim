-- ============================================
-- blink 多行预览 patch
-- ============================================
local M = {}

function M.preview_multiline_completion(item)
  local text_edits = require("blink.cmp.lib.text_edits")
  local text_edit = text_edits.get_from_item(item)

  -- AI/LSP 候选可能返回 snippet 格式；预览前先展开占位符，避免把 ${1:...}
  -- 这类 snippet 语法直接临时写进 buffer。
  if item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
    local expanded_snippet = require("blink.cmp.sources.snippets.utils").safe_parse(text_edit.newText)
    text_edit.newText = expanded_snippet and tostring(expanded_snippet) or text_edit.newText
  end

  -- blink 的多行预览是“先应用、再撤销”：这里保存 undo edit，
  -- 让补全菜单关闭或候选变化时能恢复原文。
  local original_cursor = vim.api.nvim_win_get_cursor(0)
  local undo_text_edit = text_edits.get_undo_text_edit(text_edit)
  text_edits.apply(text_edit)

  -- 命令行模式没有普通窗口光标语义；只在普通插入场景还原光标位置。
  if vim.api.nvim_get_mode().mode ~= "c" then
    vim.api.nvim_win_set_cursor(0, original_cursor)
  end

  return undo_text_edit, nil
end

function M.apply()
  package.loaded["blink.cmp.completion.accept.preview"] = M.preview_multiline_completion
end

return M
