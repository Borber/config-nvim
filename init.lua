-- ============================================
-- 基础设置
-- ============================================
vim.opt.number = true          -- 显示行号
vim.opt.relativenumber = true  -- 相对行号
vim.opt.mouse = "a"            -- 启用鼠标
vim.opt.clipboard = "unnamedplus" -- 系统剪贴板互通
vim.opt.termguicolors = true   -- 24位色:

require("config.lazy")



-- ============================================
-- Neovide 专属配置
-- ============================================
if vim.g.neovide then
  require("config.neovide")
end
