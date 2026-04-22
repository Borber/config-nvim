-- 字体：英文等宽 + 中文回退，按需替换字体名
vim.o.guifont = "Maple Mono NF, LXGW Bright, monospace"
vim.opt.linespace = 2

-- IME 输入法
vim.g.neovide_input_ime = true

-- 仅在插入/搜索模式启用 IME，Normal 模式自动关闭
local function set_ime(args)
if args.event:match("Enter$") then
    vim.g.neovide_input_ime = true
else
    vim.g.neovide_input_ime = false
end
end

local ime_input = vim.api.nvim_create_augroup("ime_input", { clear = true })
vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave" }, {
group = ime_input,
pattern = "*",
callback = set_ime,
})
vim.api.nvim_create_autocmd({ "CmdlineEnter", "CmdlineLeave" }, {
group = ime_input,
pattern = "[/\\?]",
callback = set_ime,
})

-- 缩放（4K 屏可改为 1.25 或 1.5）
vim.g.neovide_scale_factor = 1.0

-- 光标动画（不喜欢可设为 ""）
vim.g.neovide_cursor_vfx_mode = "railgun"