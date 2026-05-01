local M = {}

M.border = "single"

local border_codepoints = {
  top_left = 0x250c,
  top = 0x2500,
  top_right = 0x2510,
  right = 0x2502,
  bottom_right = 0x2518,
  bottom = 0x2500,
  bottom_left = 0x2514,
  left = 0x2502,
  left_join = 0x251c,
  right_join = 0x2524,
}

-- 用 codepoint 生成边框字符，避免源文件里直接混入不稳定的 glyph。
local function char(name)
  return vim.fn.nr2char(border_codepoints[name])
end

-- 安全读取高亮组；配色尚未加载或组不存在时回落为空表。
local function highlight(name)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  return ok and hl or {}
end

-- 暴露当前 Normal 背景色，给各插件浮窗复用统一底色。
function M.normal_bg()
  return highlight("Normal").bg
end

-- 生成普通浮窗的边框字符；传入高亮组时返回带高亮的 borderchars。
function M.borderchars(group)
  local chars = {
    char("top_left"),
    char("top"),
    char("top_right"),
    char("right"),
    char("bottom_right"),
    char("bottom"),
    char("bottom_left"),
    char("left"),
  }

  if group == nil then
    return chars
  end

  return vim
    .iter(chars)
    :map(function(value)
      return { value, group }
    end)
    :totable()
end

-- Telescope 的 borderchars 顺序和普通浮窗不同，这里单独适配。
function M.telescope_borderchars()
  return {
    char("top"),
    char("right"),
    char("bottom"),
    char("left"),
    char("top_left"),
    char("top_right"),
    char("bottom_right"),
    char("bottom_left"),
  }
end

-- 下拉 picker 分 prompt/results/preview 三段，需要额外处理连接处。
function M.telescope_dropdown_borderchars()
  return {
    prompt = {
      char("top"),
      char("right"),
      " ",
      char("left"),
      char("top_left"),
      char("top_right"),
      char("right"),
      char("left"),
    },
    results = {
      char("top"),
      char("right"),
      char("bottom"),
      char("left"),
      char("left_join"),
      char("right_join"),
      char("bottom_right"),
      char("bottom_left"),
    },
    preview = M.telescope_borderchars(),
  }
end

-- Noice 使用 { style, padding } 结构，集中入口避免各处重复写。
function M.noice_border(padding)
  return {
    style = M.border,
    padding = padding or { 0, 1 },
  }
end

-- 把插件自己的高亮组链接到统一浮窗高亮，减少重复配色定义。
local function winhighlight(groups)
  local parts = {}

  for from, to in pairs(groups) do
    table.insert(parts, from .. ":" .. to)
  end

  table.sort(parts)
  return table.concat(parts, ",")
end

function M.float_winhighlight(extra)
  -- 普通说明/预览浮窗统一走 NormalFloat，插件只需要按需补额外高亮映射。
  return winhighlight(vim.tbl_extend("force", {
    FloatBorder = "FloatBorder",
    FloatTitle = "FloatTitle",
    Normal = "NormalFloat",
    Search = "None",
  }, extra or {}))
end

function M.menu_winhighlight(extra)
  -- 补全/选择菜单统一复用 Pmenu/PmenuSel，避免各插件菜单选中态各自发散。
  return winhighlight(vim.tbl_extend("force", {
    CursorLine = "PmenuSel",
    FloatBorder = "FloatBorder",
    Normal = "Pmenu",
    Search = "None",
  }, extra or {}))
end

function M.title(text, group)
  return { { " " .. text .. " ", group or "FloatTitle" } }
end

function M.telescope_defaults()
  -- Telescope 默认项集中在这里，保证主 picker 和自定义 picker 的边框/前缀/布局一致。
  return {
    borderchars = M.telescope_borderchars(),
    entry_prefix = "   ",
    layout_config = {
      height = 0.8,
      horizontal = {
        preview_width = 0.55,
        prompt_position = "top",
      },
      width = 0.87,
    },
    prompt_prefix = " " .. vim.fn.nr2char(0xf002) .. "  ",
    selection_caret = " " .. vim.fn.nr2char(0xf105) .. " ",
    sorting_strategy = "ascending",
    winblend = 0,
  }
end

local function link(group, target)
  vim.api.nvim_set_hl(0, group, { link = target })
end

-- 配色切换后重新收拢浮窗、补全菜单和 picker 的底色与边框。
function M.apply_highlights()
  local normal = highlight("Normal")
  if normal.bg == nil then
    return
  end

  local comment = highlight("Comment")
  local cursor_line = highlight("CursorLine")
  local identifier = highlight("Identifier")
  local visual = highlight("Visual")
  local selection_bg = cursor_line.bg or visual.bg or normal.bg
  local border_fg = highlight("FloatBorder").fg or comment.fg or normal.fg
  local accent_fg = identifier.fg or border_fg

  vim.api.nvim_set_hl(0, "NormalFloat", { fg = normal.fg, bg = normal.bg })
  vim.api.nvim_set_hl(0, "FloatBorder", { fg = border_fg, bg = normal.bg })
  vim.api.nvim_set_hl(0, "FloatTitle", { fg = border_fg, bg = normal.bg })
  vim.api.nvim_set_hl(0, "FloatFooter", { fg = border_fg, bg = normal.bg })
  vim.api.nvim_set_hl(0, "Pmenu", { fg = normal.fg, bg = normal.bg })
  vim.api.nvim_set_hl(0, "PmenuSel", { fg = normal.fg, bg = selection_bg, bold = true })
  vim.api.nvim_set_hl(0, "PmenuSbar", { bg = normal.bg })
  vim.api.nvim_set_hl(0, "PmenuThumb", { bg = border_fg })

  link("BlinkCmpMenu", "Pmenu")
  link("BlinkCmpMenuBorder", "FloatBorder")
  link("BlinkCmpDoc", "NormalFloat")
  link("BlinkCmpDocBorder", "FloatBorder")
  link("BlinkCmpDocSeparator", "FloatBorder")
  link("BlinkCmpSignatureHelp", "NormalFloat")
  link("BlinkCmpSignatureHelpBorder", "FloatBorder")

  link("NoicePopup", "NormalFloat")
  link("NoicePopupBorder", "FloatBorder")
  link("NoicePopupmenu", "Pmenu")
  link("NoicePopupmenuBorder", "FloatBorder")
  link("NoiceCmdlinePopup", "NormalFloat")
  link("NoiceCmdlinePopupBorder", "FloatBorder")
  link("NoiceCmdlinePopupTitle", "FloatTitle")
  link("NoiceMini", "NormalFloat")
  link("NoiceConfirm", "NormalFloat")
  link("NoiceConfirmBorder", "FloatBorder")

  link("TelescopeNormal", "NormalFloat")
  link("TelescopePromptNormal", "NormalFloat")
  link("TelescopeResultsNormal", "NormalFloat")
  link("TelescopePreviewNormal", "NormalFloat")
  link("TelescopeBorder", "FloatBorder")
  link("TelescopePromptBorder", "FloatBorder")
  link("TelescopeResultsBorder", "FloatBorder")
  link("TelescopePreviewBorder", "FloatBorder")
  link("TelescopeTitle", "FloatTitle")
  link("TelescopePromptTitle", "FloatTitle")
  link("TelescopeResultsTitle", "FloatTitle")
  link("TelescopePreviewTitle", "FloatTitle")
  vim.api.nvim_set_hl(0, "TelescopeSelection", { fg = normal.fg, bg = selection_bg, bold = true })
  vim.api.nvim_set_hl(0, "TelescopeMatching", { fg = accent_fg, bg = normal.bg, bold = true })
  vim.api.nvim_set_hl(0, "TelescopePromptPrefix", { fg = accent_fg, bg = normal.bg })

  link("WhichKeyNormal", "NormalFloat")
  link("WhichKeyBorder", "FloatBorder")
  link("WhichKeyTitle", "FloatTitle")

  link("GitSignsPreviewBorder", "FloatBorder")
  link("GitSignsPreviewTitle", "FloatTitle")
end

return M
