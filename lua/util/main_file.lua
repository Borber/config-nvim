local M = {}

local tab_var = "main_file_bufnr"

local function is_floating_win(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end

  return vim.api.nvim_win_get_config(win).relative ~= ""
end

local function non_floating_wins(tabpage)
  local wins = {}

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    if vim.api.nvim_win_is_valid(win) and not is_floating_win(win) then
      table.insert(wins, win)
    end
  end

  return wins
end

local function get_tab_var(tabpage)
  local ok, bufnr = pcall(vim.api.nvim_tabpage_get_var, tabpage, tab_var)
  if ok and type(bufnr) == "number" then
    return bufnr
  end
end

local function set_tab_var(tabpage, bufnr)
  pcall(vim.api.nvim_tabpage_set_var, tabpage, tab_var, bufnr)
end

local function redraw()
  vim.schedule(function()
    pcall(vim.cmd, "redrawtabline")
    pcall(vim.cmd, "redrawstatus")
  end)
end

function M.is_normal_file(bufnr)
  if not bufnr or bufnr == 0 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  return vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function first_normal_file_in_tab(tabpage)
  local ok, current_win = pcall(vim.api.nvim_tabpage_get_win, tabpage)
  if ok and vim.api.nvim_win_is_valid(current_win) and not is_floating_win(current_win) then
    local bufnr = vim.api.nvim_win_get_buf(current_win)
    if M.is_normal_file(bufnr) then
      return bufnr
    end
  end

  for _, win in ipairs(non_floating_wins(tabpage)) do
    local bufnr = vim.api.nvim_win_get_buf(win)
    if M.is_normal_file(bufnr) then
      return bufnr
    end
  end
end

function M.track_current()
  local win = vim.api.nvim_get_current_win()
  if is_floating_win(win) then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  if not M.is_normal_file(bufnr) then
    return
  end

  set_tab_var(vim.api.nvim_get_current_tabpage(), bufnr)
  redraw()
end

function M.tab_buf(tabpage)
  if tabpage == nil or tabpage == 0 then
    tabpage = vim.api.nvim_get_current_tabpage()
  end

  local bufnr = get_tab_var(tabpage)
  if M.is_normal_file(bufnr) then
    return bufnr
  end

  bufnr = first_normal_file_in_tab(tabpage)
  if bufnr then
    set_tab_var(tabpage, bufnr)
  end

  return bufnr
end

function M.name(bufnr, opts)
  opts = opts or {}
  bufnr = bufnr or M.tab_buf(0)

  if not M.is_normal_file(bufnr) then
    return "[No File]"
  end

  local name = vim.api.nvim_buf_get_name(bufnr)
  if opts.path == 2 then
    return vim.fn.fnamemodify(name, ":p")
  end

  if opts.path == 1 then
    return vim.fn.fnamemodify(name, ":.")
  end

  return vim.fn.fnamemodify(name, ":t")
end

function M.status_name()
  local bufnr = M.tab_buf(0)
  local name = M.name(bufnr, { path = 1 })

  if M.is_normal_file(bufnr) then
    if vim.bo[bufnr].readonly then
      name = name .. " [RO]"
    end

    if vim.bo[bufnr].modified then
      name = name .. " [+]"
    end
  end

  return name
end

function M.tab_name(tabpage)
  if tabpage == nil or tabpage == 0 then
    tabpage = vim.api.nvim_get_current_tabpage()
  end

  local bufnr = M.tab_buf(tabpage)
  local name

  if M.is_normal_file(bufnr) then
    local ok, tabby_name = pcall(function()
      return require("tabby.feature.buf_name").get_by_bufid(bufnr, { mode = "unique" })
    end)
    name = ok and tabby_name or M.name(bufnr)
  else
    name = "[No File]"
  end

  local win_count = #non_floating_wins(tabpage)
  if win_count > 1 then
    name = string.format("%s[%d+]", name, win_count - 1)
  end

  return name
end

function M.setup()
  local group = vim.api.nvim_create_augroup("config_main_file", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "WinEnter", "TabEnter" }, {
    group = group,
    callback = M.track_current,
  })

  vim.api.nvim_create_autocmd({ "BufDelete", "WinClosed", "TabClosed" }, {
    group = group,
    callback = redraw,
  })

  M.track_current()
end

return M
