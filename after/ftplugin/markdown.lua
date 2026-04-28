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

local undo = "silent! nunmap <buffer> K"
  .. " | silent! nunmap <buffer> <localleader>mx"
  .. " | silent! xunmap <buffer> <localleader>mx"
  vim.b.undo_ftplugin = vim.b.undo_ftplugin and (vim.b.undo_ftplugin .. " | " .. undo) or undo
