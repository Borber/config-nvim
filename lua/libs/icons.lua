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
}

-- OS 图标
M.os = {
  Windows_NT = vim.fn.nr2char(0xf0372),
  Darwin = vim.fn.nr2char(0xf179),
  Linux = vim.fn.nr2char(0xf17c),
}

-- OS 检测
function M.os_icon()
  local uv = vim.uv
  local system = uv.os_uname().sysname
  return M.os[system] or "?"
end

return M
