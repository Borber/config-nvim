-- ============================================
-- 基础选项
-- ============================================
vim.g.mapleader = " "
vim.g.maplocalleader = ","

local opt = vim.opt

opt.number = true              -- 显示行号
opt.relativenumber = true     -- 相对行号
opt.mouse = "a"                -- 启用鼠标
opt.cmdheight = 0              -- 隐藏命令行空白区域
opt.showcmd = true             -- 显示未完成的命令
opt.showcmdloc = "statusline"  -- 在状态栏显示命令提示
opt.showmode = false           -- 不单独显示当前模式
opt.termguicolors = true       -- 24 位真彩色
opt.fillchars:append({ eob = " " }) -- 去掉 ~ 号
opt.signcolumn = "yes"        -- 固定保留 sign 列，避免 Git/LSP 标记挤动文本
opt.hidden = true              -- 切换缓冲区时保留未保存修改
opt.autowriteall = true        -- 切换窗口等操作时自动保存
opt.ignorecase = true          -- 搜索默认忽略大小写
opt.smartcase = true           -- 搜索词含大写时改为区分大小写
opt.hlsearch = true            -- 高亮搜索结果
opt.incsearch = true           -- 输入搜索词时即时跳转匹配

-- 延迟到 UIEnter 后再挂系统剪贴板，避免启动期 fork pbcopy/xclip 阻塞
-- 这里用 schedule 让首屏更快出现；剪贴板会在事件循环空闲时再接管。
vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)

-- filetype 自定义
vim.filetype.add({
  filename = {
    TODO = "markdown",
  },
})

-- Windows 下默认使用 pwsh，保持 UTF-8 与纯文本输出，避免 PSStyle 乱码
if vim.fn.has("win32") == 1 and vim.fn.executable("pwsh") == 1 then
  -- shellcmdflag 里显式把 PSStyle 输出设为 PlainText，避免 :! / makeprg
  -- 的结果带 ANSI 样式控制符，影响 quickfix 或命令输出阅读。
  vim.o.shell = "pwsh.exe -NoLogo"
  vim.o.shellcmdflag =
    "-ExecutionPolicy RemoteSigned -Command $PSStyle.OutputRendering = 'PlainText';"
  vim.o.shellredir = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  vim.o.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  vim.o.shellquote = ""
  vim.o.shellxquote = ""
end
