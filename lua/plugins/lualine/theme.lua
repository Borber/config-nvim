local M = {}
local color = require("util.color")
local everforest = require("util.palette").everforest

-- lualine 沿用 Everforest hard 的暖绿色系，和主配色保持一致。
local active_blend = 0.18
local wakatime_blend = 0.1

local mode_accent_names = {
  n = "green",
  i = "aqua",
  v = "blue",
  V = "blue",
  ["\22"] = "blue",
  s = "blue",
  S = "blue",
  ["\19"] = "blue",
  R = "orange",
  c = "gold",
  t = "green",
}

local section_accent_names = {
  normal = "green",
  insert = "aqua",
  visual = "blue",
  replace = "orange",
  command = "gold",
}

local function current_accent(palette)
  -- WakaTime 是动态组件，颜色跟随当前 mode，而不是只跟启动时主题表。
  local mode = vim.fn.mode()
  local name = mode_accent_names[mode] or mode_accent_names[mode:sub(1, 1)] or "green"

  return palette[name] or palette.green
end

local function tune_section(section, accent)
  if section == nil then
    return
  end

  section.a = vim.tbl_extend("force", section.a or {}, {
    fg = everforest.base,
    bg = accent,
    gui = "bold",
  })
  section.b = vim.tbl_extend("force", section.b or {}, {
    fg = accent,
    bg = everforest.surface,
    gui = "bold",
  })
  section.c = vim.tbl_extend("force", section.c or {}, {
    fg = everforest.text,
    bg = "NONE",
  })
end

function M.apply_highlights()
  -- 中段空白和未单独着色的状态栏组件都交还给终端背景，透明/毛玻璃效果由终端负责呈现。
  vim.api.nvim_set_hl(0, "StatusLine", { fg = everforest.text, bg = "NONE" })
  vim.api.nvim_set_hl(0, "StatusLineNC", { fg = everforest.muted, bg = "NONE" })
end

function M.statusline()
  local theme = {}

  for section, accent_name in pairs(section_accent_names) do
    theme[section] = {}
    tune_section(theme[section], everforest[accent_name])
  end

  theme.inactive = {
    a = { fg = everforest.muted, bg = "NONE", gui = "bold" },
    b = { fg = everforest.muted, bg = "NONE" },
    c = { fg = everforest.muted, bg = "NONE" },
  }

  return theme
end

function M.wakatime_color()
  local accent = current_accent(everforest)

  return {
    fg = accent,
    bg = color.blend_hex(accent, everforest.surface, wakatime_blend),
    gui = "bold",
  }
end

function M.buffer_active_color()
  return {
    fg = everforest.green,
    bg = color.blend_hex(everforest.green, everforest.surface, active_blend),
    gui = "bold",
  }
end

function M.buffer_inactive_color()
  return {
    fg = everforest.muted,
    bg = everforest.surface,
  }
end

return M
