-- ============================================
-- 图标集中管理
-- 所有 Nerd Font 图标唯一定义于此，避免散落各文件。
-- ============================================

local M = {}

-- LSP 诊断
M.lsp = {
  error = " ",
  warn = " ",
  hint = " ",
  info = " ",
}

-- 基础 UI
M.basic = {
  dir = "󰉋",
  dir_open = "󰉖",
  file = "󰈔",
  modified = "●",
  close = "󰅖",
  indent = "│",
}

-- Git
M.git = {
  icon = "",
  branch = "󰘬",
  commit = "󰜘",
  author = "",
  blame = "",
  delete = "╸",
  sign = "┃",
  title = "",
  staged = "",
  added = "",
  deleted = "",
  ignored = "",
  modified = "",
  renamed = "",
  unmerged = "",
  untracked = "?",
}

-- 搜索 / 查找
M.search = {
  find = "",
  grep = "",
  history = "",
  recent = "",
}

-- 树状结构
M.tree = {
  collapsed = "",
  expanded = "",
  bookmark = "◆",
  active = "✦",
}

-- LSP / Outline 符号
M.symbol = {
  File = "󰈔",
  Module = "󰆧",
  Namespace = "󰅪",
  Package = "󰏗",
  Class = "",
  Method = "󰊕",
  Property = "󰜢",
  Field = "",
  Constructor = "",
  Enum = "",
  Interface = "",
  Function = "󰊕",
  Variable = "󰀫",
  Constant = "󰏿",
  String = "󰀬",
  Number = "󰎠",
  Boolean = "󰨙",
  Array = "󰅪",
  Object = "󰅩",
  Key = "󰌋",
  Null = "󰟢",
  EnumMember = "",
  Struct = "",
  Event = "",
  Operator = "󰆕",
  TypeParameter = "󰊄",
  Component = "󰅴",
  Fragment = "󰅴",
  TypeAlias = "",
  Parameter = "",
  StaticMethod = "",
  Macro = "",
}

-- 窗口 / 工具
M.ui = {
  vim = "",
  quit = "󰈆",
  session = "",
  terminal = "",
  code = "",
  keys = "",
  hunk = "",
  explorer = "󰙅",
  new_file = "",
  config = "",
  zen = "󰖯",
  scroll_left = "",
  scroll_right = "",
  bookmark = "",
  markdown = "",
  rocket = "",
  time = "",
}

-- OS 图标
M.os = {
  Windows_NT = "󰍲",
  Darwin = "",
  Linux = "",
}

-- OS 检测（缓存结果，避免每次 statusline 刷新都调用 os_uname）
local cached_os_icon
function M.os_icon()
  if cached_os_icon then
    return cached_os_icon
  end
  local system = vim.uv.os_uname().sysname
  cached_os_icon = M.os[system] or "?"
  return cached_os_icon
end

return M
