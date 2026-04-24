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

-- 外部终端
map("n", "<localleader>n", function()
  require("util.external_terminal").open_shell()
end, { silent = true, desc = "Terminal new" })


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
