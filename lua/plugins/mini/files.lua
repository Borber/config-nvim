local M = {}
local configured = false

-- starter 的 Open 入口临时复用 mini.files 做选择器：只在那一次里启用 <S-CR> 直接打开当前项。
local enable_starter_open_key = false

local function canonical_path(path)
  -- Windows/Unix 路径统一成 /，并去掉多余尾斜杠，方便后续前缀比较。
  if path == nil or path == "" then
    return path
  end

  local normalized = vim.fs.normalize(path):gsub("\\", "/")
  normalized = normalized:gsub("^([A-Za-z]:)/+", "%1/")

  if #normalized > 3 then
    normalized = normalized:gsub("/+$", "")
  end

  return normalized
end

-- 从 cwd 向下构造分支，直到当前文件或目录所在的位置。
local function build_branch_from_cwd(cwd, path)
  if path == "" then
    return nil
  end

  local normalized_cwd = canonical_path(cwd)
  local normalized_path = canonical_path(path)
  local current_dir = vim.fn.isdirectory(path) == 1 and normalized_path or canonical_path(vim.fs.dirname(normalized_path))
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

local function is_reusable_unnamed_buffer(win_id)
  -- 启动页或空白新窗口通常是一个未命名、未修改、只有一行空内容的 buffer。
  -- 这种窗口可以直接复用，不必为了打开文件额外新建 tab。
  if win_id == nil or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end

  local buf_id = vim.api.nvim_win_get_buf(win_id)
  if vim.api.nvim_buf_get_name(buf_id) ~= "" or vim.bo[buf_id].buftype ~= "" or vim.bo[buf_id].modified then
    return false
  end

  return vim.api.nvim_buf_line_count(buf_id) == 1
    and vim.api.nvim_buf_get_lines(buf_id, 0, 1, false)[1] == ""
end

local function is_reusable_directory_buffer(win_id)
  -- :edit 目录会先留下一个目录 buffer，再由 mini.files 接管。
  -- 选中文件时应复用这个占位窗口，而不是额外开新 tab。
  if win_id == nil or not vim.api.nvim_win_is_valid(win_id) then
    return false
  end

  local buf_id = vim.api.nvim_win_get_buf(win_id)
  local name = vim.api.nvim_buf_get_name(buf_id)

  return vim.bo[buf_id].buftype == ""
    and not vim.bo[buf_id].modified
    and name ~= ""
    and vim.fn.isdirectory(name) == 1
end

local function is_reusable_target_window(win_id)
  return is_reusable_unnamed_buffer(win_id) or is_reusable_directory_buffer(win_id)
end

local function open_path(path)
  require("mini.files").close()
  require("plugins.mini.visits").open_path(path)
end

local function current_entry()
  local minifiles = require("mini.files")
  local entry = minifiles.get_fs_entry()

  if entry == nil then
    return
  end

  return minifiles, entry
end

local function open_selected_entry()
  local _, entry = current_entry()
  if entry == nil then
    return
  end

  open_path(entry.path)
end

local function open_entry()
  local minifiles, entry = current_entry()
  if entry == nil then
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

  local state = minifiles.get_explorer_state()
  local target_win = state and state.target_window

  if is_reusable_target_window(target_win) then
    -- 空白/目录占位 buffer 里打开文件时沿用当前窗口，保持启动后的第一次打开足够轻。
    minifiles.go_in({ close_on_file = true })
    return
  end

  if minifiles.close() == false then
    return
  end

  -- 已经有实际编辑内容时，文件从新 tab 打开，减少覆盖当前工作区的风险。
  vim.cmd("tabedit " .. vim.fn.fnameescape(entry.path))
end

local function open_files(root)
  local minifiles = require("mini.files")
  local cwd = vim.fs.normalize(root or vim.fn.getcwd())
  local path = vim.api.nvim_buf_get_name(0)

  -- 先以 cwd 作为锚点打开，再展开到当前文件所在位置。
  minifiles.open(cwd, false)

  local branch = build_branch_from_cwd(cwd, path)
  if branch == nil then
    return
  end

  minifiles.set_branch(branch, { depth_focus = #branch })

  if vim.fn.filereadable(path) == 1 then
    focus_file_entry(minifiles, branch[#branch], vim.fs.normalize(path))
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

      -- mini.files 里每一行就是一个文件项，s 改为按行跳转。
      vim.keymap.set("n", "s", function()
        require("hop").hint_lines()
      end, {
        buffer = buf_id,
        desc = "Hop hint lines",
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

return M
