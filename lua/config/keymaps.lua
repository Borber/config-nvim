-- ============================================
-- 全局键位
-- ============================================
local map = vim.keymap.set

-- 插入模式快捷键
map("i", "jj", "<Esc>", { silent = true, desc = "Esc" })
map("i", "<M-h>", "<Left>",  { silent = true })
map("i", "<M-j>", "<Down>",  { silent = true })
map("i", "<M-k>", "<Up>",    { silent = true })
map("i", "<M-l>", "<Right>", { silent = true })
map("i", "<M-b>", "<C-o>b",  { silent = true })
map("i", "<M-f>", "<C-o>w",  { silent = true })

-- 命令行模式快捷键（/、?、:）
map("c", "<M-h>", "<Left>",  { silent = true })
map("c", "<M-j>", "<Down>",  { silent = true })
map("c", "<M-k>", "<Up>",    { silent = true })
map("c", "<M-l>", "<Right>", { silent = true })

-- 窗口切换
map("n", "<C-h>", "<C-w>h", { silent = true })
map("n", "<C-j>", "<C-w>j", { silent = true })
map("n", "<C-k>", "<C-w>k", { silent = true })
map("n", "<C-l>", "<C-w>l", { silent = true })

-- 退出
map("n", "<leader>qq", "<Cmd>qa<CR>", { silent = true, desc = "Quit all" })
map("n", "<leader>qw", "<Cmd>wqa<CR>", { silent = true, desc = "Write and quit all" })
map("n", "<leader>qQ", "<Cmd>qa!<CR>", { silent = true, desc = "Force quit all" })

-- Buffer 切换：默认以 buffer 作为文件切换单位。
map("n", "<leader>bn", "<Cmd>bnext<CR>", { silent = true, desc = "Next buffer" })
map("n", "<leader>bp", "<Cmd>bprevious<CR>", { silent = true, desc = "Previous buffer" })

for i = 1, 9 do
  map("n", "<leader>b" .. i, "<Cmd>LualineBuffersJump " .. i .. "<CR>", {
    silent = true,
    desc = "Goto buffer " .. i,
  })
end

-- Terminal 模式：双 Esc 退出，<C-hjkl> 直接切窗
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { silent = true, desc = "Leave terminal mode" })
map("t", "<C-h>", [[<C-\><C-n><C-w>h]], { silent = true })
map("t", "<C-j>", [[<C-\><C-n><C-w>j]], { silent = true })
map("t", "<C-k>", [[<C-\><C-n><C-w>k]], { silent = true })
map("t", "<C-l>", [[<C-\><C-n><C-w>l]], { silent = true })

-- 外部终端
map("n", "<leader>tn", function()
  require("util.external_terminal").open_shell()
end, { silent = true, desc = "Terminal new (external)" })


-- :R 重载 lua/ 下所有模块并重新 source init.lua
-- 用于开发配置时热更新（不重启 Neovim）
vim.api.nvim_create_user_command("R", function()
  for name, _ in pairs(package.loaded) do
    if name:match("^config") or name:match("^util") or name:match("^plugins") then
      package.loaded[name] = nil
    end
  end
  dofile(vim.env.MYVIMRC)
  vim.notify("Reloaded config", vim.log.levels.INFO)
end, { desc = "Reload Neovim config" })
