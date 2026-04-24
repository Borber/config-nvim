-- ============================================
-- 基础设置
-- ============================================
vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.opt.number = true          -- 显示行号
vim.opt.relativenumber = false  -- 相对行号
vim.opt.mouse = "a"            -- 启用鼠标
vim.opt.clipboard = "unnamedplus" -- 系统剪贴板互通
vim.opt.cmdheight = 0          -- 隐藏命令行空白区域
vim.opt.showcmd = true         -- 显示未完成的命令
vim.opt.showcmdloc = "statusline" -- 在状态栏显示命令提示
vim.opt.showmode = false       -- 不单独显示当前模式
vim.opt.termguicolors = true   -- 24位色:
vim.opt.fillchars:append({ eob = " " }) -- 去掉 ~ 号
vim.opt.hidden = true          -- 允许切换缓冲区时保留未保存修改
vim.opt.autowriteall = true    -- 切换窗口等操作时自动保存
vim.opt.ignorecase = true     -- 搜索默认忽略大小写
vim.opt.smartcase = true      -- 搜索词含大写时改为区分大小写
vim.opt.hlsearch = true       -- 高亮搜索结果
vim.opt.incsearch = true      -- 输入搜索词时即时跳转匹配

vim.keymap.set("i", "jj", "<Esc>", { silent = true })

-- 插入模式快速移动
vim.keymap.set("i", "<M-h>", "<Left>", { silent = true })
vim.keymap.set("i", "<M-j>", "<Down>", { silent = true })
vim.keymap.set("i", "<M-k>", "<Up>", { silent = true })
vim.keymap.set("i", "<M-l>", "<Right>", { silent = true })
vim.keymap.set("i", "<M-b>", "<C-o>b", { silent = true })
vim.keymap.set("i", "<M-f>", "<C-o>w", { silent = true })

local external_terminal = require("config.external_terminal")

vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true })
vim.keymap.set("n", "<localleader>n", function()
  external_terminal.open_shell()
end, { silent = true, desc = "Terminal new" })

if vim.fn.has("win32") == 1 then
    vim.opt.shell = "pwsh -NoLogo"
    vim.opt.shellcmdflag = "-ExecutionPolicy RemoteSigned -Command "
    vim.opt.shellquote = ""
    vim.opt.shellxquote = ""
    vim.opt.shellredir = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
    vim.opt.shellpipe = "2>&1 | Tee-Object -Encoding UTF8 %s; exit $LastExitCode"
end

vim.filetype.add({
  filename = {
    TODO = "markdown",
  },
})

require("patch.unnamed")

require("config.lazy")

-- ============================================
-- Neovide 专属配置
-- ============================================
if vim.g.neovide then
  require("config.neovide")
end
