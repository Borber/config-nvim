-- ============================================
-- 基础设置
-- ============================================
vim.opt.number = true          -- 显示行号
vim.opt.relativenumber = false  -- 相对行号
vim.opt.mouse = "a"            -- 启用鼠标
vim.opt.clipboard = "unnamedplus" -- 系统剪贴板互通
vim.opt.termguicolors = true   -- 24位色:
vim.opt.fillchars:append({ eob = " " }) -- 去掉 ~ 号
vim.opt.hidden = true
vim.opt.autowriteall = true

vim.keymap.set("i", "jj", "<Esc>", { silent = true })

require("config.unnamed_markdown")

require("config.lazy")

-- ============================================
-- Neovide 专属配置
-- ============================================
if vim.g.neovide then
  require("config.neovide")
end
