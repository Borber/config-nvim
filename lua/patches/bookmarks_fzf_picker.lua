-- ============================================
-- bookmarks.nvim fzf-lua picker
-- ============================================
local M = {}

local function default_bookmark_display(bookmark, bookmarks)
  local max_name = 15
  local max_filename = 20
  local max_filepath = 20

  for _, item in ipairs(bookmarks) do
    max_name = math.max(max_name, #(item.name or ""))
    max_filename = math.max(max_filename, #vim.fn.fnamemodify(item.location.path, ":t"))
    max_filepath = math.max(max_filepath, #vim.fn.pathshorten(item.location.path))
  end

  max_name = math.min(max_name, 30)
  max_filename = math.min(max_filename, 30)
  max_filepath = math.min(max_filepath, 40)

  local name = bookmark.name or ""
  local filename = vim.fn.fnamemodify(bookmark.location.path, ":t")
  local path = vim.fn.pathshorten(bookmark.location.path)

  if #name > max_name then
    name = name:sub(1, max_name - 2) .. ".."
  else
    name = name .. string.rep(" ", max_name - #name)
  end

  if #filename > max_filename then
    filename = filename:sub(1, max_filename - 2) .. ".."
  else
    filename = filename .. string.rep(" ", max_filename - #filename)
  end

  if #path > max_filepath then
    path = path:sub(1, max_filepath - 2) .. ".."
  else
    path = path .. string.rep(" ", max_filepath - #path)
  end

  return string.format("%s | %s | %s", name, filename, path)
end

local function bookmark_display(bookmarks)
  return function(bookmark)
    local configured = vim.g.bookmarks_config and vim.g.bookmarks_config.picker and vim.g.bookmarks_config.picker.entry_display
    local display = type(configured) == "function" and configured or default_bookmark_display
    return display(bookmark, bookmarks)
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

function M.apply()
  package.loaded["bookmarks.picker"] = {
    pick_bookmark = pick_bookmark,
    grep_bookmark = grep_bookmark,
    pick_bookmark_list = pick_bookmark_list,
    pick_commands = pick_commands,
  }
end

return M
