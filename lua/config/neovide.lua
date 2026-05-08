-- 字体：英文等宽 + 中文回退，按需替换字体名
local is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1
local is_macos = vim.fn.has("macunix") == 1
local font_family = "Maple Mono NF, LXGW Bright, monospace"
local default_font_size = is_windows and 17 or 22

vim.g.gui_font_size = vim.g.gui_font_size or default_font_size
vim.g.gui_default_font_size = vim.g.gui_default_font_size or vim.g.gui_font_size

local function set_font_size(size)
  size = math.max(8, tonumber(size) or vim.g.gui_default_font_size)
  vim.g.gui_font_size = size
  vim.o.guifont = string.format("%s:h%d", font_family, size)
end

local function paste_system_clipboard()
  local text = vim.fn.getreg("+")
  if text == "" then
    return
  end

  vim.api.nvim_paste(text, true, -1)
end

set_font_size(vim.g.gui_font_size)

vim.keymap.set("n", "<C-=>", function()
  set_font_size(vim.g.gui_font_size + 1)
end, { silent = true, desc = "增大字体" })

vim.keymap.set("n", "<C-->", function()
  set_font_size(vim.g.gui_font_size - 1)
end, { silent = true, desc = "减小字体" })

vim.keymap.set("n", "<C-0>", function()
  set_font_size(vim.g.gui_default_font_size)
end, { silent = true, desc = "重置字体" })

vim.keymap.set({ "n", "i", "x", "c", "t" }, "<C-S-v>", paste_system_clipboard, {
  silent = true,
  desc = "粘贴系统剪贴板",
})

vim.opt.linespace = 2
vim.g.neovide_theme = "light"
vim.g.neovide_floating_shadow = false
vim.g.neovide_refresh_rate = 144
vim.g.neovide_refresh_rate_idle = 5

-- Neovide 标题栏显示当前工作目录，而不是当前文件名。
vim.o.title = true
vim.o.titlestring = "%{fnamemodify(getcwd(), ':~')}"

if is_macos then
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"
end

-- 缩放：macOS 上默认略微放大，其他平台保持原始比例。
vim.g.neovide_scale_factor = is_macos and 1.1 or 1.0

-- 光标动画
vim.g.neovide_cursor_animation_length = 0.45
vim.g.neovide_cursor_trail_size = 1.50
vim.g.neovide_cursor_vfx_mode = "pixiedust"
