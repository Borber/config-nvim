-- ============================================
-- 基础选项
-- ============================================
vim.loader.enable()
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt
if vim.fn.exists("&winborder") == 1 then
  opt.winborder = "single" -- 默认让插件浮窗保持直角矩形边框。
end
opt.number = true              -- 显示行号
opt.relativenumber = true     -- 相对行号
opt.mouse = "a"                -- 启用鼠标
opt.cmdheight = 0              -- 隐藏命令行空白区域
opt.showcmd = true             -- 显示未完成的命令
opt.showcmdloc = "statusline"  -- 在状态栏显示命令提示
opt.showmode = false           -- 不单独显示当前模式
opt.termguicolors = true       -- 24 位真彩色
opt.fileformats = { "unix", "dos" } -- 识别 LF/CRLF；新文件默认使用 LF
opt.fillchars:append({
  eob = " ",    -- 去掉 ~ 号
  diff = " ",   -- 隐藏 diff filler 横线
})
opt.foldlevelstart = 99        -- 新窗口默认全展开，LSP 折叠不自动收拢
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldtext = "v:lua.ConfigFoldText()"
local fold_prefix = "◇ "
local fold_prefix_width = vim.fn.strdisplaywidth(fold_prefix)

local function fold_start_text()
  -- 只按当前实际 fold 范围取首行，避免 LSP fold 边界和 Treesitter node 尾部预览不一致。
  return { { vim.fn.getline(vim.v.foldstart), "" } }
end

local function add_fold_prefix(parts)
  local first = parts[1]
  if type(first) ~= "table" or type(first[1]) ~= "string" then
    table.insert(parts, 1, { fold_prefix, "ConfigFoldPrefix" })
    return parts
  end

  local leading = first[1]:match("^ *") or ""
  local indent = leading:sub(1, math.max(#leading - fold_prefix_width, 0))
  first[1] = first[1]:sub(#leading + 1)

  if indent ~= "" then
    table.insert(parts, 1, { indent, first[2] or "" })
    table.insert(parts, 2, { fold_prefix, "ConfigFoldPrefix" })
    return parts
  end

  table.insert(parts, 1, { fold_prefix, "ConfigFoldPrefix" })
  return parts
end

-- 自定义折叠行文本：保留首行位置，只在行尾补预览和高亮行数。
function _G.ConfigFoldText()
  local hidden_count = vim.v.foldend - vim.v.foldstart
  local parts = add_fold_prefix(fold_start_text())

  local end_text = vim.trim(vim.fn.getline(vim.v.foldend))
  if end_text ~= "" then
    table.insert(parts, { " ⋯ ", "ConfigFoldMuted" })
    table.insert(parts, { end_text, "ConfigFoldPreview" })
  end

  table.insert(parts, { "   ↙ [" .. hidden_count .. " lines hidden]", "ConfigFoldTail" })
  return parts
end
opt.signcolumn = "yes:1"       -- 常驻一格 sign 列，避免诊断/书签出现时挤动文本
opt.numberwidth = 2            -- 行号列保持紧凑，超过两位时由 Neovim 自动扩展。
opt.hidden = true              -- 切换缓冲区时保留未保存修改
opt.autowriteall = true        -- 切换窗口等操作时自动保存
opt.undofile = true            -- 跨启动保留撤销历史
opt.confirm = true             -- 关闭/切换未保存 buffer 时给出确认
opt.splitright = true          -- 纵向分屏默认在右侧打开
opt.splitbelow = true          -- 横向分屏默认在下方打开
opt.cursorline = true          -- 高亮当前行，降低大文件中光标定位成本
opt.updatetime = 250           -- 更快触发 CursorHold / Git / LSP 刷新
opt.timeoutlen = 400           -- 缩短 leader 组合键等待时间
opt.inccommand = "split"       -- :substitute 时在预览窗口中展示结果
opt.list = true                -- 显示制表符/行尾空白等不可见字符
opt.listchars = {
  tab = "» ",                  -- 制表符显示成可见缩进箭头
  trail = "·",                 -- 行尾空白显示成点
  nbsp = "␣",                  -- 不换行空格单独标出来
}
opt.ignorecase = true          -- 搜索默认忽略大小写
opt.smartcase = true           -- 搜索词含大写时改为区分大小写
opt.hlsearch = true            -- 高亮搜索结果
opt.incsearch = true           -- 输入搜索词时即时跳转匹配
opt.scrolloff = 999            -- 尽量让光标行保持在窗口中间
opt.jumpoptions:append("view") -- 返回跳转列表/标记/标签栈位置时尽量恢复原窗口视图

-- 使用更稳定的 diff 算法，并在行内变更较多时保持更好的对齐效果。
opt.diffopt:append({ "algorithm:histogram", "indent-heuristic", "linematch:60" })

if vim.fn.executable("rg") == 1 then
  -- 让 :grep 走 ripgrep，并输出 quickfix 能直接解析的 file:line:col 格式。
  opt.grepprg = "rg --vimgrep --smart-case"
  opt.grepformat = "%f:%l:%c:%m"
end

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

-- Windows 下默认使用 pwsh，保持 UTF-8 与纯文本输出，避免 profile/PSStyle 干扰
if vim.fn.has("win32") == 1 then
  -- shellcmdflag 里显式把 PSStyle 输出设为 PlainText，避免 :! / makeprg
  -- 的结果带 ANSI 样式控制符，影响 quickfix 或命令输出阅读。
  vim.o.shell = "pwsh -NoLogo "
  vim.o.shellcmdflag = "-NoProfile -ExecutionPolicy RemoteSigned -Command $PSStyle.OutputRendering = 'PlainText';"
  vim.o.shellredir = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  vim.o.shellpipe = "2>&1 | Out-File -Encoding UTF8 %s; exit $LastExitCode"
  vim.o.shellquote = ""
  vim.o.shellxquote = ""
end
