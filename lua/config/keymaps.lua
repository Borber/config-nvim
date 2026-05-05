-- ============================================
-- 全局基础键位
-- 本文件只定义不依赖插件的全局基础键位。
-- 插件自身的键位优先放在其插件规格文件中（lua/plugins/*.lua）。
-- ============================================
local map = vim.keymap.set

-- ============================================
-- 插入模式
-- ============================================
map("i", "jj", "<Esc>", { silent = true, desc = "Esc" })
map("i", "<M-h>", "<Left>", { silent = true })
map("i", "<M-j>", "<Down>", { silent = true })
map("i", "<M-k>", "<Up>", { silent = true })
map("i", "<M-l>", "<Right>", { silent = true })
map("i", "<M-b>", "<C-o>b", { silent = true })
map("i", "<M-f>", "<C-o>w", { silent = true })

-- ============================================
-- 命令行模式（/、?、:）
-- ============================================
map("c", "<M-h>", "<Left>", { silent = true })
map("c", "<M-j>", "<Down>", { silent = true })
map("c", "<M-k>", "<Up>", { silent = true })
map("c", "<M-l>", "<Right>", { silent = true })

-- ============================================
-- 窗口管理
-- ============================================
map("n", "<C-h>", "<C-w>h", { silent = true })
map("n", "<C-j>", "<C-w>j", { silent = true })
map("n", "<C-k>", "<C-w>k", { silent = true })
map("n", "<C-l>", "<C-w>l", { silent = true })
map("n", "<C-Left>", function()
  require("util.window").resize_current_edge("left")
end, { silent = true, desc = "Move window edge left" })
map("n", "<C-Down>", function()
  require("util.window").resize_current_edge("down")
end, { silent = true, desc = "Move window edge down" })
map("n", "<C-Up>", function()
  require("util.window").resize_current_edge("up")
end, { silent = true, desc = "Move window edge up" })
map("n", "<C-Right>", function()
  require("util.window").resize_current_edge("right")
end, { silent = true, desc = "Move window edge right" })
map({ "n", "t" }, "<leader>x", function()
  require("util.window").close_current()
end, { silent = true, desc = "Close current layer" })

-- ============================================
-- Buffer 管理
-- ============================================
map("n", "<leader>bn", "<Cmd>bnext<CR>", { silent = true, desc = "Next buffer" })
map("n", "<leader>bp", "<Cmd>bprevious<CR>", { silent = true, desc = "Previous buffer" })

-- ============================================
-- 退出 / 会话
-- ============================================
map("n", "<leader>qq", "<Cmd>qa<CR>", { silent = true, desc = "Quit all" })
map("n", "<leader>qw", "<Cmd>wqa<CR>", { silent = true, desc = "Write and quit all" })
map("n", "<leader>qQ", "<Cmd>qa!<CR>", { silent = true, desc = "Force quit all" })

-- ============================================
-- Terminal 模式：双 Esc 退出，<C-hjkl> 直接切窗
-- ============================================
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { silent = true, desc = "Leave terminal mode" })
map("t", "<C-h>", [[<C-\><C-n><C-w>h]], { silent = true })
map("t", "<C-j>", [[<C-\><C-n><C-w>j]], { silent = true })
map("t", "<C-k>", [[<C-\><C-n><C-w>k]], { silent = true })
map("t", "<C-l>", [[<C-\><C-n><C-w>l]], { silent = true })

-- ============================================
-- 终端 / 外部工具
-- ============================================
map("n", "<leader>tn", function()
  require("util.external_terminal").open_shell()
end, { silent = true, desc = "Terminal new (external)" })
