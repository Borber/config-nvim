local function markdown_link_target()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local from = 1

  while from <= #line do
    local start_col, end_col, target = line:find("%[[^%]]-%]%((.-)%)", from)
    if start_col == nil then
      break
    end

    if col >= start_col and col <= end_col then
      return target
    end

    from = end_col + 1
  end

  local start_col, end_col, autolink = line:find("<(https?://[^>]+)>")
  if start_col ~= nil and col >= start_col and col <= end_col then
    return autolink
  end
end

local function open_markdown_target()
  local target = markdown_link_target()
  if target == nil or target == "" then
    vim.cmd.normal({ args = { "K" }, bang = true })
    return
  end

  if target:match("^https?://") then
    vim.ui.open(target)
    return
  end

  local path = target:gsub("#.*$", "")
  if path == "" then
    return
  end

  local base = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local resolved = vim.fs.normalize(vim.fs.joinpath(base, path))

  vim.cmd("edit " .. vim.fn.fnameescape(resolved))
end

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, {
    buffer = true,
    desc = desc,
    silent = true,
    remap = type(rhs) == "string" and rhs:match("^<Plug>") ~= nil,
  })
end

map("n", "K", open_markdown_target, "Open markdown link")
map({ "n", "x" }, "<localleader>mx", "<Plug>(MarkdownPlusToggleCheckbox)", "Toggle checkbox")

local function has_buffer_keymap(bufnr, mode, lhs)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  for _, keymap in ipairs(vim.api.nvim_buf_get_keymap(bufnr, mode)) do
    if keymap.lhs == lhs then
      return true
    end
  end

  return false
end

function _G.ConfigMarkdownUndoFtplugin(bufnr)
  -- ftplugin 可能被重复加载；映射本来不存在时跳过，真实删除失败才通知。
  for _, map_spec in ipairs({
    { mode = "n", lhs = "K" },
    { mode = "n", lhs = "<localleader>mx" },
    { mode = "x", lhs = "<localleader>mx" },
  }) do
    if has_buffer_keymap(bufnr, map_spec.mode, map_spec.lhs) then
      local ok, err = pcall(vim.keymap.del, map_spec.mode, map_spec.lhs, { buffer = bufnr })
      if not ok then
        vim.notify("Failed to remove markdown mapping " .. map_spec.lhs .. ": " .. tostring(err), vim.log.levels.ERROR)
      end
    end
  end
end

local undo = ("lua _G.ConfigMarkdownUndoFtplugin(%d)"):format(vim.api.nvim_get_current_buf())
vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
