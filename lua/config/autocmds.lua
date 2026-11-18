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

-- Markdown 的标题折叠由 Treesitter 处理；其它文件优先使用支持折叠的 LSP。
local treesitter_foldexpr = "v:lua.vim.treesitter.foldexpr()"
local lsp_foldexpr = "v:lua.vim.lsp.foldexpr()"

local function update_foldexpr(bufnr)
  if not buffer_util.is_normal_file(bufnr) then
    return
  end

  local foldexpr = treesitter_foldexpr
  if vim.bo[bufnr].filetype ~= "markdown" and #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/foldingRange" }) > 0 then
    foldexpr = lsp_foldexpr
  end

  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
    local opts = vim.wo[win][0]
    local current = opts.foldexpr
    if current ~= foldexpr and (current == treesitter_foldexpr or current == lsp_foldexpr) then
      opts.foldexpr = foldexpr
    end
  end
end

vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "LspAttach", "LspDetach" }, {
  group = augroup("ConfigFolding", { clear = true }),
  callback = function(event)
    if event.event == "BufWinEnter" or event.event == "FileType" then
      update_foldexpr(event.buf)
      return
    end

    -- LspAttach / LspDetach 触发时，client 的 buffer 关联还没更新。
    vim.schedule(function()
      update_foldexpr(event.buf)
    end)
  end,
  desc = "Use native LSP folding when available",
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
