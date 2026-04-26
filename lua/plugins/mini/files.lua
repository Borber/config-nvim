local M = {}
local configured = false

local function canonical_path(path)
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

local function toggle_files()
  local minifiles = require("mini.files")
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  local path = vim.api.nvim_buf_get_name(0)

  if not minifiles.close() then
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
      use_as_default_explorer = true,
    },
    windows = {
      preview = true,
      width_preview = 60,
    },
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("ConfigMiniFiles", { clear = true }),
    pattern = "MiniFilesBufferCreate",
    callback = function(args)
      local buf_id = args.data.buf_id

      vim.keymap.set("n", "<Esc>", function()
        require("mini.files").close()
      end, {
        buffer = buf_id,
        desc = "Close explorer",
        silent = true,
      })
    end,
  })
end

function M.toggle()
  M.setup()
  toggle_files()
end

return M
