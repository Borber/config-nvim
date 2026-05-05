-- ============================================
-- 模块说明
-- ============================================
-- 集中定义浮窗边框、winhighlight 和配色接线，保证 Telescope / Noice / Lazy / LSP 等浮窗风格一致。
local M = {}

M.border = "single"

-- ============================================
-- 边框字符
-- ============================================
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

local function highlight(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false })
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

-- ============================================
-- 窗口高亮
-- ============================================
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

-- ============================================
-- Telescope 默认项
-- ============================================
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

-- ============================================
-- 高亮调色板
-- ============================================
local function set_hl(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local function link(group, target)
  set_hl(group, { link = target })
end

local function link_many(groups, target)
  for _, group in ipairs(groups) do
    link(group, target)
  end
end

local function current_palette()
  local normal = highlight("Normal")
  if normal.bg == nil then
    return
  end

  local comment = highlight("Comment")
  local cursor_line = highlight("CursorLine")
  local identifier = highlight("Identifier")
  local visual = highlight("Visual")

  local selection_bg = cursor_line.bg or visual.bg or normal.bg
  local tab_bg = cursor_line.bg or normal.bg
  local tab_active_bg = visual.bg or cursor_line.bg or normal.bg
  local border_fg = highlight("FloatBorder").fg or comment.fg or normal.fg
  local accent_fg = identifier.fg or border_fg

  return {
    normal = normal,
    comment = comment,
    cursor_line = cursor_line,
    selection_bg = selection_bg,
    tab_bg = tab_bg,
    tab_active_bg = tab_active_bg,
    border_fg = border_fg,
    accent_fg = accent_fg,
  }
end

-- ============================================
-- 插件高亮
-- ============================================
local function apply_base_highlights(palette)
  local normal = palette.normal

  set_hl("NormalFloat", { fg = normal.fg, bg = normal.bg })
  set_hl("FloatBorder", { fg = palette.border_fg, bg = normal.bg })
  set_hl("FloatTitle", { fg = palette.border_fg, bg = normal.bg })
  set_hl("FloatFooter", { fg = palette.border_fg, bg = normal.bg })
  set_hl("Pmenu", { fg = normal.fg, bg = normal.bg })
  set_hl("PmenuSel", { fg = normal.fg, bg = palette.selection_bg, bold = true })
  set_hl("PmenuSbar", { bg = normal.bg })
  set_hl("PmenuThumb", { bg = palette.border_fg })
end

local function apply_blink_highlights()
  link("BlinkCmpMenu", "Pmenu")
  link_many({ "BlinkCmpDoc", "BlinkCmpSignatureHelp" }, "NormalFloat")
  link_many({
    "BlinkCmpMenuBorder",
    "BlinkCmpDocBorder",
    "BlinkCmpDocSeparator",
    "BlinkCmpSignatureHelpBorder",
  }, "FloatBorder")
end

local function apply_noice_highlights()
  link_many({ "NoicePopup", "NoiceCmdlinePopup", "NoiceMini", "NoiceConfirm" }, "NormalFloat")
  link_many({ "NoicePopupBorder", "NoiceCmdlinePopupBorder", "NoiceConfirmBorder" }, "FloatBorder")
  link("NoicePopupmenu", "Pmenu")
  link("NoicePopupmenuBorder", "FloatBorder")
  link("NoiceCmdlinePopupTitle", "FloatTitle")
end

local function apply_lazy_highlights(palette)
  local normal = palette.normal

  set_hl("LazyNormal", { fg = normal.fg, bg = normal.bg })
  set_hl("LazyBackdrop", { bg = normal.bg })
  set_hl("LazyH1", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  set_hl("LazyH2", { fg = palette.border_fg, bg = normal.bg, bold = true })
  set_hl("LazyButton", { fg = normal.fg, bg = normal.bg })
  set_hl("LazyButtonActive", { fg = normal.fg, bg = palette.selection_bg, bold = true })
  set_hl("LazySpecial", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  set_hl("LazyProgressDone", { fg = palette.accent_fg, bg = normal.bg })
  set_hl("LazyProgressTodo", { fg = palette.comment.fg, bg = normal.bg })
  set_hl("LazyTab", { fg = normal.fg, bg = palette.tab_bg })
  set_hl("LazyTabKey", { fg = palette.accent_fg, bg = palette.tab_bg, bold = true })
  set_hl("LazyTabSep", { fg = palette.tab_bg, bg = normal.bg })
  set_hl("LazyTabActive", { fg = normal.fg, bg = palette.tab_active_bg, bold = true })
  set_hl("LazyTabActiveKey", { fg = palette.accent_fg, bg = palette.tab_active_bg, bold = true })
  set_hl("LazyTabActiveSep", { fg = palette.tab_active_bg, bg = normal.bg })
  link_many({ "LazyDimmed", "LazyProp" }, "Comment")
  link("LazyTaskOutput", "NormalFloat")
end

local function apply_telescope_highlights(palette)
  local normal = palette.normal

  link_many({
    "TelescopeNormal",
    "TelescopePromptNormal",
    "TelescopeResultsNormal",
    "TelescopePreviewNormal",
  }, "NormalFloat")
  link_many({
    "TelescopeBorder",
    "TelescopePromptBorder",
    "TelescopeResultsBorder",
    "TelescopePreviewBorder",
  }, "FloatBorder")
  link_many({
    "TelescopeTitle",
    "TelescopePromptTitle",
    "TelescopeResultsTitle",
    "TelescopePreviewTitle",
  }, "FloatTitle")
  set_hl("TelescopeSelection", { fg = normal.fg, bg = palette.selection_bg, bold = true })
  set_hl("TelescopeMatching", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  set_hl("TelescopePromptPrefix", { fg = palette.accent_fg, bg = normal.bg })
end

local function apply_small_plugin_highlights()
  link("WhichKeyNormal", "NormalFloat")
  link("WhichKeyBorder", "FloatBorder")
  link("WhichKeyTitle", "FloatTitle")
  link("GitSignsPreviewBorder", "FloatBorder")
  link("GitSignsPreviewTitle", "FloatTitle")
end

local function apply_editor_highlights(palette)
  local normal = palette.normal
  local comment = palette.comment
  local cursor_line = palette.cursor_line

  -- 折叠行：注释色 + 斜体，融入 Normal 底色，安静地标记折叠区域。
  set_hl("Folded", {
    fg = comment.fg,
    italic = true,
  })
  set_hl("CursorLineFold", {
    fg = comment.fg,
    bg = cursor_line.bg or normal.bg,
    italic = true,
  })
  set_hl("ConfigFoldPrefix", {
    fg = palette.accent_fg,
    bold = true,
  })
  set_hl("ConfigFoldMuted", {
    fg = comment.fg,
  })
  set_hl("ConfigFoldPreview", {
    fg = comment.fg,
    italic = true,
  })
  set_hl("ConfigFoldTail", {
    fg = palette.accent_fg,
    bold = true,
    italic = true,
  })

  -- mini.indentscope：使用比注释色更浅的线条，安静地标示当前作用域。
  set_hl("MiniIndentscopeSymbol", {
    fg = palette.border_fg,
  })
end

-- ============================================
-- 对外入口
-- ============================================
function M.apply_highlights()
  local palette = current_palette()
  if palette == nil then
    return
  end

  apply_base_highlights(palette)
  apply_blink_highlights()
  apply_noice_highlights()
  apply_lazy_highlights(palette)
  apply_telescope_highlights(palette)
  apply_small_plugin_highlights()
  apply_editor_highlights(palette)
end

return M
