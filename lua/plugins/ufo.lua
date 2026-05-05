-- ============================================
-- nvim-ufo：折叠 provider + foldtext 自定义渲染
-- ============================================
-- 1. provider：lsp 主，indent 兜底（ufo 只允许 `{ main, fallback }` 二元组合）。
--    markdown 由 `after/ftplugin/markdown.lua` 调用 `ufo.detach()` 退回到
--    `vim.treesitter.foldexpr()` + 默认 foldtext，保留 render-markdown.nvim
--    的 hl_eol 标题背景。
-- 2. handler：在 ufo 给出的首行 virtText 上拼 `◇ ` 前缀、` ⋯` 折叠提示和
--    `[N lines hidden]` 尾部；不显示末行预览。

return {
  "kevinhwang91/nvim-ufo",
  dependencies = { "kevinhwang91/promise-async" },
  event = "VeryLazy",
  init = function()
    -- ufo 推荐 options：完全展开 + 大 foldlevel 让 provider 自由产出。
    vim.o.foldlevel = 99
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true

    -- 向所有 LSP server 广播 foldingRange capability，使 ufo 的 lsp provider
    -- 能拿到块级折叠范围（rust-analyzer / clangd / lua_ls 等均支持）。
    vim.lsp.config("*", {
      capabilities = {
        textDocument = {
          foldingRange = {
            dynamicRegistration = false,
            lineFoldingOnly = true,
          },
        },
      },
    })
  end,
  opts = function()
    return {
      open_fold_hl_timeout = 0, -- 关闭展开折叠后的高亮闪烁，避免“选中区域再消失”的观感。
      provider_selector = function()
        return { "lsp", "indent" }
      end,
      fold_virt_text_handler = function(virt_text, lnum, end_lnum, _, _, _)
        -- 把 `◇ ` 拼到首行原有缩进尾部（替换两格缩进），避免在 column 0 直接前置
        -- 让正文整体右移；缩进不足两格时退化为前置。
        local first = virt_text[1]
        local leading = first and first[1]:match("^ *") or ""
        local result = {}
        if #leading >= 2 then
          first[1] = first[1]:sub(#leading + 1)
          if first[1] == "" then
            table.remove(virt_text, 1)
          end
          local keep = leading:sub(1, #leading - 2)
          if keep ~= "" then
            result[#result + 1] = { keep, "" }
          end
        end
        result[#result + 1] = { "◇ ", "ConfigFoldPrefix" }
        vim.list_extend(result, virt_text)
        result[#result + 1] = { " ⋯", "ConfigFoldMuted" }
        result[#result + 1] = { "   ↙ [" .. (end_lnum - lnum) .. " lines hidden]", "ConfigFoldTail" }
        return result
      end,
    }
  end,
  keys = {
    { "zR", function() require("ufo").openAllFolds() end, desc = "Fold: open all" },
    { "zM", function() require("ufo").closeAllFolds() end, desc = "Fold: close all" },
    { "zp", function() require("ufo").peekFoldedLinesUnderCursor() end, desc = "Fold: peek" },
  },
  config = function(_, opts)
    require("ufo").setup(opts)
  end,
}
