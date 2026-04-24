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

-- 窗口切换
map("n", "<C-h>", "<C-w>h", { silent = true })
map("n", "<C-j>", "<C-w>j", { silent = true })
map("n", "<C-k>", "<C-w>k", { silent = true })
map("n", "<C-l>", "<C-w>l", { silent = true })

-- <leader>1..9 直接跳到第 N 个 tab（用 Vim 原生 {count}gt，无需 closure）
for i = 1, 9 do
  map("n", "<leader>t" .. i, i .. "gt", { silent = true, desc = "Goto tab " .. i })
end

-- Terminal 模式：双 Esc 退出，<C-hjkl> 直接切窗
map("t", "<Esc><Esc>", [[<C-\><C-n>]], { silent = true, desc = "Leave terminal mode" })
map("t", "<C-h>", [[<C-\><C-n><C-w>h]], { silent = true })
map("t", "<C-j>", [[<C-\><C-n><C-w>j]], { silent = true })
map("t", "<C-k>", [[<C-\><C-n><C-w>k]], { silent = true })
map("t", "<C-l>", [[<C-\><C-n><C-w>l]], { silent = true })

-- 外部终端
map("n", "<localleader>tn", function()
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

-- :CheckKeymapConflicts 按需加载 keymap 冲突检测
-- 仅当手动调用时才会 monkey-patch vim.keymap.set，避免常驻开销
vim.api.nvim_create_user_command("CheckKeymapConflicts", function()
  require("util.keymap_conflicts").setup()
  vim.cmd("CheckKeymapConflicts")
end, { desc = "Enable & show keymap conflicts" })
