local M = {}
local buffer_util = require("libs.buffer")
local path_util = require("libs.path")
local canonical_path = path_util.canonical

local syncing_focused_window = false

-- 从当前 cwd 和当前文件/目录构造 mini.files 需要的 branch 列表。
-- 这一步的目标不是“打开文件”，而是让文件树先落到项目根，再展开到实际上下文。
local function build_branch_from_cwd(cwd, path, stat_cache)
  if path == "" then
    return nil
  end

  local normalized_cwd = canonical_path(cwd)
  local normalized_path = canonical_path(path)
  local current_dir = path_util.is_directory(path, stat_cache) and normalized_path or canonical_path(vim.fs.dirname(normalized_path))
  local branch = { current_dir }
  local cwd_ancestor_pattern = string.format("^%s/.", vim.pesc(normalized_cwd))

  while branch[1] ~= normalized_cwd and branch[1]:find(cwd_ancestor_pattern) ~= nil do
    table.insert(branch, 1, canonical_path(vim.fs.dirname(branch[1])))
  end

  if branch[1] ~= normalized_cwd then
    return nil
  end

  return branch
end

local function focus_file_entry(minifiles, directory_path, file_path)
  local state = minifiles.get_explorer_state()
  if state == nil then
    return
  end

  -- 先定位到对应目录窗口，再在那一列里把光标挪到目标文件行。
  local target_win
  for _, window in ipairs(state.windows) do
    if canonical_path(window.path) == directory_path then
      target_win = window.win_id
      break
    end
  end

  if target_win == nil or not vim.api.nvim_win_is_valid(target_win) then
    return
  end

  local buf_id = vim.api.nvim_win_get_buf(target_win)
  local line_count = vim.api.nvim_buf_line_count(buf_id)

  for line = 1, line_count do
    local entry = minifiles.get_fs_entry(buf_id, line)
    if entry ~= nil and canonical_path(entry.path) == file_path then
      vim.api.nvim_set_current_win(target_win)
      vim.api.nvim_win_set_cursor(target_win, { line, 0 })
      return
    end
  end
end

local function window_path(windows, win_id)
  if windows == nil then
    return
  end

  for _, window in ipairs(windows) do
    if window.win_id == win_id then
      return window.path
    end
  end
end

local function open_file(minifiles, path, line)
  if minifiles.close() == false then
    return
  end

  -- 关闭文件树后直接 :edit 真实文件，保留 buffer 列表里的复用行为。
  vim.cmd("edit " .. vim.fn.fnameescape(path))

  if line == nil then
    return
  end

  local target_line = math.min(math.max(line, 1), vim.api.nvim_buf_line_count(0))
  vim.api.nvim_win_set_cursor(0, { target_line, 0 })
end

local function current_entry()
  local minifiles = require("mini.files")
  local entry = minifiles.get_fs_entry()

  if entry == nil then
    return
  end

  return minifiles, entry
end

local function hide_reusable_target_placeholder(minifiles)
  local state = minifiles.get_explorer_state()
  local target_win = state and state.target_window

  -- target_window 有时会复用成一个空 listed buffer；这里把它降回 unlisted，避免污染 buffer 列表。
  if not buffer_util.window_has_reusable_placeholder(target_win) then
    return
  end

  local target_buf = vim.api.nvim_win_get_buf(target_win)
  vim.bo[target_buf].buflisted = false
end

function M.open_entry()
  local minifiles, entry = current_entry()
  if minifiles == nil or entry == nil then
    return
  end

  if entry.fs_type == "directory" then
    -- 支持像 2<CR> 这样的 count，一次跨过多层目录。
    for _ = 1, vim.v.count1 do
      minifiles.go_in()
    end
    return
  end

  if entry.fs_type ~= "file" then
    return
  end

  open_file(minifiles, entry.path)
end

function M.open_root(root)
  local minifiles = require("mini.files")
  local cwd = canonical_path(root or vim.fn.getcwd())
  local path = vim.api.nvim_buf_get_name(0)
  local stat_cache = {}

  -- 先在项目根打开，再按当前 buffer 的位置展开 branch。
  minifiles.open(cwd, false)
  hide_reusable_target_placeholder(minifiles)

  local branch = build_branch_from_cwd(cwd, path, stat_cache)
  if branch == nil then
    return
  end

  minifiles.set_branch(branch, { depth_focus = #branch })

  if path_util.is_file(path, stat_cache) then
    focus_file_entry(minifiles, branch[#branch], canonical_path(path))
  end
end

function M.sync_focus_to_current_window()
  if syncing_focused_window then
    return
  end

  local minifiles = package.loaded["mini.files"]
  if minifiles == nil or type(minifiles.get_explorer_state) ~= "function" then
    return
  end

  local state = minifiles.get_explorer_state()
  if state == nil or state.windows == nil or state.branch == nil then
    return
  end

  local current_path = window_path(state.windows, vim.api.nvim_get_current_win())

  -- 只在当前窗口确实是目录列时才同步，避免预览窗或普通窗口误触发。
  if not path_util.is_directory(current_path) then
    return
  end

  local target_depth
  local normalized_current_path = canonical_path(current_path)
  for depth, branch_path in ipairs(state.branch) do
    if canonical_path(branch_path) == normalized_current_path then
      target_depth = depth
      break
    end
  end

  if target_depth == nil or target_depth == state.depth_focus then
    return
  end

  syncing_focused_window = true
  local ok, err = pcall(minifiles.set_branch, state.branch, { depth_focus = target_depth })
  syncing_focused_window = false
  if not ok then
    error(err)
  end
end

function M.handle_hop_line_jump(jump_target)
  local minifiles = package.loaded["mini.files"]
  if minifiles == nil or type(minifiles.get_explorer_state) ~= "function" then
    return false
  end

  local state = minifiles.get_explorer_state()
  local path = window_path(state and state.windows, jump_target.window)
  if not path_util.is_file(path) then
    return false
  end

  -- Hop 落到预览窗口时，直接打开真实文件并把光标停在命中的行。
  open_file(minifiles, path, jump_target.cursor.row)
  return true
end

return M
