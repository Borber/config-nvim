local M = {}

-- 只淡化 b 段的背景，让左侧从 mode 主色自然过渡到 diagnostics 底色。
local section_b_blend = 0.18

local section_accent_names = {
  normal = "rose",
  insert = "foam",
  visual = "iris",
  replace = "pine",
  command = "love",
}

local function blend_hex(fg, bg, alpha)
  local function channel(hex, start)
    return tonumber(hex:sub(start, start + 1), 16) or 0
  end

  local r = math.floor(channel(fg, 2) * alpha + channel(bg, 2) * (1 - alpha) + 0.5)
  local g = math.floor(channel(fg, 4) * alpha + channel(bg, 4) * (1 - alpha) + 0.5)
  local b = math.floor(channel(fg, 6) * alpha + channel(bg, 6) * (1 - alpha) + 0.5)

  return string.format("#%02x%02x%02x", r, g, b)
end

local function tune_section(section, palette, accent)
  if section == nil then
    return
  end

  section.b = vim.tbl_extend("force", section.b or {}, {
    fg = accent,
    bg = blend_hex(accent, palette.surface, section_b_blend),
    gui = "bold",
  })
  section.c = vim.tbl_extend("force", section.c or {}, {
    fg = palette.text,
    bg = palette.surface,
  })
end

function M.statusline()
  local ok_theme, theme = pcall(require, "lualine.themes.rose-pine")
  local ok_palette, palette = pcall(require, "rose-pine.palette")
  if not ok_theme or not ok_palette then
    return "auto"
  end

  theme = vim.deepcopy(theme)

  -- 基于 rose-pine 原主题微调，不重写整套 palette，避免和主题更新脱节。
  for section, accent_name in pairs(section_accent_names) do
    tune_section(theme[section], palette, palette[accent_name])
  end

  return theme
end

return M
