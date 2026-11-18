-- ============================================
-- bookmarks.nvim fzf-lua picker
-- ============================================
local function fit_column(text, width)
  local cells = vim.fn.strdisplaywidth(text)
  if cells > width then
    local prefix
    local length = width - 2
    repeat
      prefix = vim.fn.strcharpart(text, 0, length, true)
      cells = vim.fn.strdisplaywidth(prefix)
      length = length - 1
    until cells <= width - 2
    text = prefix .. ".."
    cells = cells + 2
  end

  return text .. string.rep(" ", width - cells)
end

local function bookmark_display(bookmarks)
  local config = vim.g.bookmarks_config
  local display = config and config.picker and config.picker.entry_display
  if type(display) == "function" then
    return function(bookmark)
      return display(bookmark, bookmarks)
    end
  end

  local rows = {}
  local widths = { 15, 20, 20 }
  local limits = { 30, 30, 40 }
  for _, bookmark in ipairs(bookmarks) do
    local path = bookmark.location.path
    local columns = {
      vim.fn.strtrans(bookmark.name or ""),
      vim.fn.strtrans(vim.fn.fnamemodify(path, ":t")),
      vim.fn.strtrans(vim.fn.pathshorten(path)),
    }
    rows[bookmark] = columns
    for i, text in ipairs(columns) do
      widths[i] = math.min(limits[i], math.max(widths[i], vim.fn.strdisplaywidth(text)))
    end
  end

  return function(bookmark)
    local columns = rows[bookmark]
    return table.concat({
      fit_column(columns[1], widths[1]),
      fit_column(columns[2], widths[2]),
      fit_column(columns[3], widths[3]),
    }, " | ")
  end
end

local function pick_bookmark(callback, opts)
  opts = opts or {}

  local repo = require("bookmarks.domain.repo")
  local node = require("bookmarks.domain.node")
  local list = repo.ensure_and_get_active_list()
  local bookmarks = opts.bookmarks or node.get_all_bookmarks(list)

  require("util.fzf_picker").select(bookmarks, {
    prompt = opts.prompt or ("Bookmarks in [" .. list.name .. "]"),
    format_item = bookmark_display(bookmarks),
  }, callback)
end

local function grep_bookmark(opts)
  opts = opts or {}

  local repo = require("bookmarks.domain.repo")
  local node = require("bookmarks.domain.node")
  local active_list = repo.ensure_and_get_active_list()
  local bookmarks = node.get_all_bookmarks(active_list)
  local files = {}
  local seen = {}

  for _, bookmark in ipairs(bookmarks) do
    local path = bookmark.location.path
    if path and not seen[path] then
      seen[path] = true
      table.insert(files, path)
    end
  end

  if #files == 0 then
    vim.notify("No bookmarked files", vim.log.levels.INFO)
    return
  end

  require("fzf-lua").live_grep(vim.tbl_extend("force", {
    prompt = "Grep Bookmarked Files> ",
    search_paths = files,
  }, opts))
end

local function pick_bookmark_list(callback, opts)
  opts = opts or {}

  local repo = require("bookmarks.domain.repo")
  require("util.fzf_picker").select(repo.find_lists(), {
    prompt = opts.prompt or "Bookmark Lists",
    format_item = function(list)
      return list.name
    end,
  }, callback)
end

local function pick_commands(opts)
  opts = opts or {}

  local commands = {}
  for name, func in pairs(require("bookmarks.commands").get_all_commands()) do
    if type(func) == "function" then
      table.insert(commands, {
        name = name,
        execute = func,
      })
    end
  end

  table.sort(commands, function(a, b)
    return a.name < b.name
  end)

  require("util.fzf_picker").select(commands, {
    prompt = opts.prompt or "Bookmarks Commands",
    format_item = function(command)
      return command.name
    end,
  }, function(command)
    if command then
      command.execute()
    end
  end)
end

return {
  pick_bookmark = pick_bookmark,
  grep_bookmark = grep_bookmark,
  pick_bookmark_list = pick_bookmark_list,
  pick_commands = pick_commands,
}
