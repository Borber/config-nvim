-- ============================================
-- 模块说明
-- ============================================
-- 集中定义浮窗边框、winhighlight 和配色接线，保证 fzf-lua / Noice / LSP 等浮窗风格一致。
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

function M.panel_winhighlight(extra)
  -- 右侧工具 split 复用浮窗底色和边线，避免 Outline 这类侧栏单独发散。
  return M.float_winhighlight(vim.tbl_extend("force", {
    CursorLine = "PmenuSel",
    EndOfBuffer = "NormalFloat",
    FoldColumn = "NormalFloat",
    SignColumn = "NormalFloat",
    WinSeparator = "FloatBorder",
  }, extra or {}))
end

function M.title(text, group)
  return { { " " .. text .. " ", group or "FloatTitle" } }
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
  local comment = highlight("Comment")
  local cursor_line = highlight("CursorLine")
  local diagnostic_warn = highlight("DiagnosticWarn")
  local directory = highlight("Directory")
  local identifier = highlight("Identifier")
  local pmenu_sel = highlight("PmenuSel")
  local visual = highlight("Visual")

  normal.bg = normal.bg or "NONE"

  -- 选中态优先使用真正的选区色，避免 CursorLine 对比度不合适时污染浮窗菜单。
  local selection_bg = visual.bg or pmenu_sel.bg or cursor_line.bg or normal.bg
  local border_fg = highlight("FloatBorder").fg or comment.fg or normal.fg
  local accent_fg = directory.fg or identifier.fg or border_fg
  local warn_fg = diagnostic_warn.fg or accent_fg

  return {
    normal = normal,
    comment = comment,
    cursor_line = cursor_line,
    directory = directory,
    diagnostic_warn = diagnostic_warn,
    selection_bg = selection_bg,
    border_fg = border_fg,
    accent_fg = accent_fg,
    warn_fg = warn_fg,
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

local function apply_fzf_lua_highlights(palette)
  local normal = palette.normal

  -- fzf-lua 的外层浮窗和内层 fzf 终端各有一套高亮组，需要同时接到统一调色板。
  set_hl("FzfLuaNormal", { fg = normal.fg, bg = normal.bg })
  set_hl("FzfLuaPreviewNormal", { fg = normal.fg, bg = normal.bg })
  set_hl("FzfLuaBorder", { fg = palette.border_fg, bg = normal.bg })
  set_hl("FzfLuaPreviewBorder", { fg = palette.border_fg, bg = normal.bg })
  set_hl("FzfLuaTitle", { fg = palette.border_fg, bg = normal.bg })
  set_hl("FzfLuaPreviewTitle", { fg = palette.border_fg, bg = normal.bg })
  set_hl("FzfLuaBackdrop", { bg = normal.bg })
  set_hl("FzfLuaCursor", { fg = normal.fg, bg = palette.selection_bg, bold = true })
  set_hl("FzfLuaCursorLine", { fg = normal.fg, bg = palette.selection_bg, bold = true })
  set_hl("FzfLuaSearch", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  set_hl("FzfLuaHeaderBind", { fg = palette.accent_fg, bg = normal.bg })
  set_hl("FzfLuaHeaderText", { fg = normal.fg, bg = normal.bg })

  link_many({
    "FzfLuaHelpNormal",
    "FzfLuaFzfNormal",
    "FzfLuaFzfQuery",
  }, "NormalFloat")
  set_hl("FzfLuaFzfGutter", { fg = normal.fg, bg = normal.bg })
  link_many({
    "FzfLuaHelpBorder",
    "FzfLuaFzfBorder",
    "FzfLuaFzfScrollbar",
    "FzfLuaFzfSeparator",
  }, "FloatBorder")
  link_many({
    "FzfLuaHelpTitle",
    "FzfLuaFzfHeader",
  }, "FloatTitle")
  set_hl("FzfLuaFzfCursorLine", { fg = normal.fg, bg = palette.selection_bg, bold = true })
  set_hl("FzfLuaFzfMatch", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  set_hl("FzfLuaFzfInfo", { fg = palette.comment.fg, bg = normal.bg })
  set_hl("FzfLuaFzfPointer", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  link_many({ "FzfLuaFzfMarker", "FzfLuaFzfSpinner", "FzfLuaFzfPrompt" }, "FzfLuaFzfPointer")
end

local function apply_mini_files_highlights(palette)
  local normal = palette.normal

  -- mini.files 默认继承 CursorLine / NormalFloat；这里显式覆盖，保证文件树跟当前主题一致。
  set_hl("MiniFilesNormal", { fg = normal.fg, bg = normal.bg })
  set_hl("MiniFilesBorder", { fg = palette.border_fg, bg = normal.bg })
  set_hl("MiniFilesBorderModified", { fg = palette.warn_fg, bg = normal.bg, bold = true })
  set_hl("MiniFilesCursorLine", { fg = normal.fg, bg = palette.selection_bg, bold = true })
  set_hl("MiniFilesDirectory", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  set_hl("MiniFilesFile", { fg = normal.fg, bg = normal.bg })
  set_hl("MiniFilesTitle", { fg = palette.border_fg, bg = normal.bg })
  set_hl("MiniFilesTitleFocused", { fg = palette.accent_fg, bg = normal.bg, bold = true })
end

local function apply_mini_clue_highlights(palette)
  local normal = palette.normal

  set_hl("MiniClueBorder", { fg = palette.border_fg, bg = normal.bg })
  set_hl("MiniClueTitle", { fg = palette.border_fg, bg = normal.bg })
  set_hl("MiniClueNextKey", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  set_hl("MiniClueNextKeyWithPostkeys", { fg = palette.warn_fg, bg = normal.bg, bold = true })
  set_hl("MiniClueSeparator", { fg = palette.border_fg, bg = normal.bg })
  set_hl("MiniClueDescGroup", { fg = palette.accent_fg, bg = normal.bg })
  set_hl("MiniClueDescSingle", { fg = normal.fg, bg = normal.bg })
end

local function apply_small_plugin_highlights()
  link("GitSignsPreviewBorder", "FloatBorder")
  link("GitSignsPreviewTitle", "FloatTitle")
end

local function apply_outline_highlights(palette)
  local normal = palette.normal

  set_hl("OutlineCurrent", { fg = normal.fg, bg = palette.selection_bg, bold = true })
  set_hl("OutlineFoldMarker", { fg = palette.accent_fg, bg = normal.bg, bold = true })
  set_hl("OutlineGuides", { fg = palette.border_fg, bg = normal.bg })
  link("OutlineDetails", "Comment")
  link("OutlineLineno", "LineNr")
  link("OutlineHelpTip", "Comment")
  link("OutlineJumpHighlight", "Visual")
  link("OutlineStatusFt", "Type")
  link("OutlineStatusProvider", "Special")
  link("OutlineStatusError", "ErrorMsg")
  link("OutlineKeymapHelpKey", "Special")
  link("OutlineKeymapHelpDisabled", "Comment")
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
  apply_fzf_lua_highlights(palette)
  apply_mini_files_highlights(palette)
  apply_mini_clue_highlights(palette)
  apply_small_plugin_highlights()
  apply_outline_highlights(palette)
  apply_editor_highlights(palette)
end

return M
