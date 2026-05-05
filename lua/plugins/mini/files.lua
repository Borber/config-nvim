local M = {}
local configured = false
local buffer_util = require("libs.buffer")
local path_util = require("libs.path")
local canonical_path = path_util.canonical

-- Starter 的 Open 复用 mini.files 做选择器；只有这个入口启用 <S-CR> 切换项目/文件上下文。
local enable_starter_open_key = false
local syncing_focused_window = false

-- 从 cwd 向下构造分支，直到当前文件或目录所在的位置。
local function build_branch_from_cwd(cwd, path, stat_cache)
  if path == "" then
    return nil
  end

  local normalized_cwd = canonical_path(cwd)
  local normalized_path = canonical_path(path)
  local current_dir = path_util.is_directory(path, stat_cache) and normalized_path or canonical_path(vim.fs.dirname(normalized_path))
  local branch = { current_dir }
  local cwd_ancestor_pattern = string.format("^%s/.", vim.pesc(normalized_cwd))

  -- mini.files 的 set_branch 需要从根到叶子的目录列表，
  -- 所以这里从当前目录一路向上补齐到 cwd。
  while branch[1] ~= normalized_cwd and branch[1]:find(cwd_ancestor_pattern) ~= nil do
    table.insert(branch, 1, canonical_path(vim.fs.dirname(branch[1])))
  end

  if branch[1] ~= normalized_cwd then
    return nil
  end

  return branch
end

-- 在最深一列里把光标移动到当前文件对应的那一行。
local function focus_file_entry(minifiles, directory_path, file_path)
  local state = minifiles.get_explorer_state()
  if state == nil then
    return
  end

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

local function open_path(path)
  require("mini.files").close()
  require("plugins.mini.visits").open_path(path)
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

  -- buffer-first：用 :edit 保留空白占位 buffer 的编号，已打开文件仍留在 buffer 列表里。
  vim.cmd("edit " .. vim.fn.fnameescape(path))

  if line == nil then
    return
  end

  local target_line = math.min(math.max(line, 1), vim.api.nvim_buf_line_count(0))
  vim.api.nvim_win_set_cursor(0, { target_line, 0 })
end

local function current_entry(minifiles)
  minifiles = minifiles or require("mini.files")
  local entry = minifiles.get_fs_entry()

  if entry == nil then
    return
  end

  return minifiles, entry
end

local function open_selected_entry()
  -- Starter Open 的最终确认走 visits.open_path，这一步才记录 recent project 并切换项目。
  local _, entry = current_entry()
  if entry == nil then
    return
  end

  open_path(entry.path)
end

local function hide_reusable_target_placeholder(minifiles)
  -- mini.files 会保留一个目标窗口给之后打开文件；如果目标是空占位，先从 buffer 列表隐藏。
  -- 真正 :edit 文件时 Neovim 会复用这个 buffer，并自动把它恢复成 listed 的文件 buffer。
  local state = minifiles.get_explorer_state()
  local target_win = state and state.target_window

  if not buffer_util.window_has_reusable_placeholder(target_win) then
    return
  end

  local target_buf = vim.api.nvim_win_get_buf(target_win)
  vim.bo[target_buf].buflisted = false
end

local function sync_focus_to_current_window()
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

local function open_entry()
  local minifiles, entry = current_entry()
  if minifiles == nil or entry == nil then
    return
  end

  if entry.fs_type == "directory" then
    -- 支持 2<CR> 这类 count 操作，一次进入多层目录。
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

local function open_files(root)
  local minifiles = require("mini.files")
  local cwd = canonical_path(root or vim.fn.getcwd())
  local path = vim.api.nvim_buf_get_name(0)
  local stat_cache = {}

  -- 先以 cwd 作为锚点打开，再展开到当前文件所在位置。
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

function M.setup()
  if configured then
    return
  end

  configured = true

  require("mini.files").setup({
    mappings = {
      go_in_plus = "<CR>",
    },
    options = {
      use_as_default_explorer = false,
    },
    windows = {
      preview = true,
      width_preview = 60,
    },
  })

  require("plugins.hop.line_jump").register(M.handle_hop_line_jump)

  local group = vim.api.nvim_create_augroup("ConfigMiniFiles", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MiniFilesBufferCreate",
    callback = function(args)
      local buf_id = args.data.buf_id

      -- 这些键位只绑定到 mini.files 的临时 buffer，离开文件树后不会污染全局键位。
      vim.keymap.set("n", "<Esc>", function()
        require("mini.files").close()
      end, {
        buffer = buf_id,
        desc = "Close explorer",
        silent = true,
      })

      vim.keymap.set("n", "<CR>", open_entry, {
        buffer = buf_id,
        desc = "Open entry",
        silent = true,
      })

      if enable_starter_open_key then
        vim.keymap.set("n", "<S-CR>", open_selected_entry, {
          buffer = buf_id,
          desc = "Open selected path",
          silent = true,
        })
      end

      vim.keymap.set("n", "l", open_entry, {
        buffer = buf_id,
        desc = "Open entry",
        silent = true,
      })
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MiniFilesExplorerClose",
    callback = function()
      enable_starter_open_key = false
    end,
  })

  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    callback = sync_focus_to_current_window,
  })
end

function M.toggle()
  M.setup()

  enable_starter_open_key = false

  local minifiles = require("mini.files")
  if minifiles.close() then
    return
  end

  open_files()
end

function M.open(path)
  M.setup()

  local root = path or vim.fn.getcwd()
  require("mini.files").close()
  enable_starter_open_key = true
  open_files(root)
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

  -- Hop 到文件预览行时，直接打开真实文件并保留目标行号。
  open_file(minifiles, path, jump_target.cursor.row)
  return true
end

return M
