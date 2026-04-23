-- 字体：英文等宽 + 中文回退，按需替换字体名
local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
local is_macos = vim.fn.has("macunix") == 1
local font_size = is_windows and 17 or 21
vim.o.guifont = string.format("Maple Mono NF, LXGW Bright, monospace:h%d", font_size)
vim.opt.linespace = 2
vim.g.neovide_theme = "light"
vim.g.neovide_floating_shadow = false
vim.g.neovide_refresh_rate = 144
vim.g.neovide_refresh_rate_idle = 5

if is_macos then
	vim.g.neovide_input_macos_option_key_is_meta = "only_left"
end

-- 缩放（4K 屏可改为 1.25 或 1.5）
vim.g.neovide_scale_factor = 1.0

-- 光标动画
vim.g.neovide_cursor_vfx_mode = "pixiedust"