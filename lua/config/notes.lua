local M = {}
local api = vim.api

-- ============================================
-- 默认配置
-- ============================================
local default_root = "~/Dropbox/note"
local default_drawer_width = 48

-- ============================================
-- 本机配置
-- ============================================
-- 私有 config.local 可覆盖笔记根目录和抽屉宽度；缺失时保持默认值。
local function local_notes_config()
  local ok, local_config = pcall(require, "config.local")
  if not ok or type(local_config) ~= "table" then
    return {}
  end

  return type(local_config.notes) == "table" and local_config.notes or {}
end

local function notes_config()
  local config = local_notes_config()

  return {
    root = config.root or default_root,
    drawer_width = config.drawer_width or default_drawer_width,
  }
end

-- ============================================
-- 路径与文件名
-- ============================================
local function normalize_path(path)
  local absolute = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
  local real = vim.uv.fs_realpath(absolute)

  -- macOS 云盘目录可能把 ~/Dropbox 解析成 CloudStorage 真实路径；
  -- 用 realpath 参与比较，避免同一 notes 目录被识别成两个入口。
  if real ~= nil then
    return vim.fs.normalize(real)
  end

  return absolute
end

local function notes_root()
  return normalize_path(notes_config().root)
end

local function notes_file(filename)
  return vim.fs.joinpath(notes_root(), filename)
end

-- ============================================
-- 日期与 journal 路径
-- ============================================
-- 测试或临时调试时可固定“今天”的日期，避免依赖真实当天。
local function today_date()
  if type(vim.g.config_notes_today) == "string" and vim.g.config_notes_today:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return vim.g.config_notes_today
  end

  return os.date("%Y-%m-%d")
end

local function journal_file(date)
  local year, month, day = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  -- 每月按第几周拆目录，避免 journal 文件在单层堆积。
  local week = tostring(math.floor((tonumber(day) - 1) / 7) + 1)

  return vim.fs.joinpath("journal", year, month, week, date .. ".md")
end

-- ============================================
-- 文件系统准备
-- ============================================
local function ensure_notes_root()
  local root = notes_root()
  local mkdir_ok, mkdir_result = pcall(vim.fn.mkdir, root, "p")
  local ok = (mkdir_ok and mkdir_result == 1) or vim.uv.fs_stat(root) ~= nil

  if not ok then
    vim.notify("Failed to create notes root: " .. root, vim.log.levels.ERROR)
  end

  return ok
end

local function ensure_file_parent(path)
  local parent = vim.fs.dirname(path)
  local mkdir_ok, mkdir_result = pcall(vim.fn.mkdir, parent, "p")
  local ok = (mkdir_ok and mkdir_result == 1) or vim.uv.fs_stat(parent) ~= nil

  if not ok then
    vim.notify("Failed to create notes directory: " .. parent, vim.log.levels.ERROR)
  end

  return ok
end

-- ============================================
-- 抽屉窗口识别
-- ============================================
local function notes_drawer_width()
  local width = tonumber(notes_config().drawer_width) or default_drawer_width
  return math.max(32, math.floor(width))
end

local function path_in_notes_root(path)
  local root = notes_root():gsub("[/\\]+$", "")
  local normalized = normalize_path(path)

  -- Windows 路径比较大小写不敏感，统一小写避免误判 notes buffer。
  if vim.fn.has("win32") == 1 then
    root = root:lower()
    normalized = normalized:lower()
  end

  return vim.startswith(normalized, root .. "/") or normalized == root
end

local function same_path(left, right)
  left = normalize_path(left)
  right = normalize_path(right)

  if vim.fn.has("win32") == 1 then
    left = left:lower()
    right = right:lower()
  end

  return left == right
end

local function is_notes_buffer(bufnr)
  local name = api.nvim_buf_get_name(bufnr)
  return name ~= "" and path_in_notes_root(name)
end

local function notes_windows()
  local wins = {}

  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_config(win).relative == "" and is_notes_buffer(api.nvim_win_get_buf(win)) then
      table.insert(wins, win)
    end
  end

  return wins
end

local function notes_window()
  return notes_windows()[1]
end

local function notes_window_for_path(path)
  for _, win in ipairs(notes_windows()) do
    local name = api.nvim_buf_get_name(api.nvim_win_get_buf(win))
    if same_path(name, path) then
      return win
    end
  end
end

local function close_notes_window(win)
  local ok, err = pcall(api.nvim_win_close, win, false)
  if not ok then
    vim.notify("Failed to close notes drawer: " .. tostring(err), vim.log.levels.WARN)
  end

  return ok
end

local function close_extra_notes_windows(keep)
  for _, win in ipairs(notes_windows()) do
    if win ~= keep then
      close_notes_window(win)
    end
  end
end

-- ============================================
-- 抽屉窗口布局
-- ============================================
-- 复用当前 tab 内唯一 notes 抽屉；旧状态里若残留多个 notes split，先收掉多余窗口。
local function focus_notes_window()
  local win = notes_window()
  if win ~= nil then
    close_extra_notes_windows(win)
    api.nvim_set_current_win(win)
    return
  end

  -- 找不到现成 notes 窗口时，在最右侧创建固定宽度 split。
  vim.cmd("rightbelow vsplit")
  vim.cmd("wincmd L")
  api.nvim_win_set_width(0, notes_drawer_width())
  vim.wo.winfixwidth = true
end

local function set_drawer_options()
  vim.bo.buflisted = false
  vim.wo.winfixwidth = true
end

-- 打开笔记时默认展开折叠，减少追加 inbox/journal 前的上下文干扰。
local function open_all_folds()
  pcall(function()
    vim.cmd("normal! zR")
  end)
  vim.wo.foldlevel = 99
end

-- ============================================
-- 笔记文件切换
-- ============================================
local function open_notes_path(path)
  if not ensure_notes_root() or not ensure_file_parent(path) then
    return
  end

  focus_notes_window()
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  set_drawer_options()
  open_all_folds()
end

-- 三个 notes 入口共用同一套规则：当前已是目标文件则关闭，否则复用抽屉切到目标文件。
local function toggle_notes_file(filename)
  return function()
    local path = notes_file(filename)
    if notes_window_for_path(path) ~= nil and M.close_drawer() then
      return
    end

    open_notes_path(path)
  end
end

-- ============================================
-- 对外入口
-- ============================================
function M.close_drawer()
  local wins = notes_windows()
  if #wins == 0 then
    return false
  end

  local closed = false
  for _, win in ipairs(wins) do
    closed = close_notes_window(win) or closed
  end

  return closed
end

M.toggle = toggle_notes_file("index.md")
M.toggle_inbox = toggle_notes_file("inbox.md")

function M.setup()
  local toggle_journal = function()
    toggle_notes_file(journal_file(today_date()))()
  end

  api.nvim_create_user_command("Notes", M.toggle, {
    desc = "Toggle global Markdown notes drawer",
    force = true,
  })

  api.nvim_create_user_command("NotesInbox", M.toggle_inbox, {
    desc = "Toggle global Markdown inbox",
    force = true,
  })

  api.nvim_create_user_command("NotesJournal", toggle_journal, {
    desc = "Toggle global Markdown journal",
    force = true,
  })

  vim.keymap.set("n", "<leader>nn", M.toggle, { silent = true, desc = "Toggle notes" })
  vim.keymap.set("n", "<leader>ni", M.toggle_inbox, { silent = true, desc = "Toggle notes inbox" })
  vim.keymap.set("n", "<leader>nj", toggle_journal, { silent = true, desc = "Toggle notes journal" })
end

return M
