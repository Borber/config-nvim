-- ============================================
-- 启动与全局入口
-- ============================================
vim.loader.enable()

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt

-- ============================================
-- 界面与基础显示
-- ============================================
if vim.fn.exists("&winborder") == 1 then
  opt.winborder = "single" -- 默认让插件浮窗保持直角矩形边框。
end

opt.termguicolors = true -- 24 位真彩色
opt.mouse = "a" -- 启用鼠标
opt.cmdheight = 0 -- 隐藏命令行空白区域
opt.showcmd = true -- 显示未完成的命令
opt.showcmdloc = "statusline" -- 在状态栏显示命令提示
opt.showmode = false -- 不单独显示当前模式
opt.cursorline = true -- 高亮当前行，降低大文件中光标定位成本
opt.scrolloff = 999 -- 尽量让光标行保持在窗口中间

opt.number = true -- 显示行号
opt.relativenumber = true -- 相对行号
opt.signcolumn = "yes:1" -- 常驻一格 sign 列，避免诊断/书签出现时挤动文本
opt.numberwidth = 2 -- 行号列保持紧凑，超过两位时由 Neovim 自动扩展。

opt.fillchars:append({
  eob = " ", -- 去掉 ~ 号
  diff = " ", -- 隐藏 diff filler 横线
})

opt.list = true -- 显示制表符/行尾空白等不可见字符
opt.listchars = {
  tab = "» ", -- 制表符显示成可见缩进箭头
  trail = "·", -- 行尾空白显示成点
  nbsp = "␣", -- 不换行空格单独标出来
}

-- ============================================
-- 编辑、缓冲区与文件格式
-- ============================================
opt.fileformats = { "unix", "dos" } -- 识别 LF/CRLF；新文件默认使用 LF
opt.hidden = true -- 切换缓冲区时保留未保存修改
opt.autoread = true -- 外部进程改动文件后，配合 checktime 自动回读。
opt.autowriteall = true -- 切换窗口等操作时自动保存
opt.undofile = true -- 跨启动保留撤销历史
opt.confirm = true -- 关闭/切换未保存 buffer 时给出确认

-- ============================================
-- 窗口布局与交互时序
-- ============================================
opt.splitright = true -- 纵向分屏默认在右侧打开
opt.splitbelow = true -- 横向分屏默认在下方打开
opt.updatetime = 250 -- 更快触发 CursorHold / Git / LSP 刷新
opt.timeoutlen = 850 -- 缩短 leader 组合键等待时间

-- ============================================
-- 折叠显示
-- ============================================
-- nvim-ufo 在 VeryLazy 后接管 foldmethod / foldexpr / foldtext；基础展开状态提前写入，
-- 避免首个真实文件在 provider 接管前出现默认折叠。
opt.foldlevel = 99
opt.foldlevelstart = 99
opt.foldenable = true

-- ============================================
-- 搜索、替换与跳转
-- ============================================
opt.ignorecase = true -- 搜索默认忽略大小写
opt.smartcase = true -- 搜索词含大写时改为区分大小写
opt.hlsearch = true -- 高亮搜索结果
opt.incsearch = true -- 输入搜索词时即时跳转匹配
opt.inccommand = "split" -- :substitute 时在预览窗口中展示结果
opt.jumpoptions:append("view") -- 返回跳转列表/标记/标签栈位置时尽量恢复原窗口视图

-- ============================================
-- Diff 与 quickfix 搜索
-- ============================================
-- 使用更稳定的 diff 算法，并在行内变更较多时保持更好的对齐效果。
opt.diffopt:append({ "algorithm:histogram", "indent-heuristic", "linematch:60" })

if vim.fn.executable("rg") == 1 then
  -- 让 :grep 走 ripgrep，并输出 quickfix 能直接解析的 file:line:col 格式。
  opt.grepprg = "rg --vimgrep --smart-case"
  opt.grepformat = "%f:%l:%c:%m"
end

-- ============================================
-- 剪贴板与文件类型
-- ============================================
-- 延后一轮事件循环再挂系统剪贴板，避免启动期 fork pbcopy/xclip 阻塞首屏。
vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)

vim.filetype.add({
  filename = {
    TODO = "markdown",
  },
})

-- ============================================
-- Windows shell
-- ============================================
if vim.fn.has("win32") == 1 then
  -- 默认使用 pwsh，并显式关闭 profile/ANSI 样式，保持 :!、makeprg 和 quickfix 输出稳定。
  vim.o.shell = "pwsh -NoLogo "
  vim.o.shellcmdflag = "-NoProfile -ExecutionPolicy RemoteSigned -Command $PSStyle.OutputRendering = 'PlainText';"
  vim.o.shellredir = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  vim.o.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  vim.o.shellquote = ""
  vim.o.shellxquote = ""
end
