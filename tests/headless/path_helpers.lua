local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)

local tmp_root = vim.fn.tempname()
vim.fn.delete(tmp_root, "rf")
vim.fn.mkdir(tmp_root, "p")

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual: %s", message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function temp_path(...)
  return vim.fs.joinpath(tmp_root, ...)
end

local path = require("libs.path")
local file = temp_path("project", "main.lua")
local dir = vim.fs.dirname(file)
vim.fn.mkdir(dir, "p")
vim.fn.writefile({ "print('ok')" }, file)

local stat_cache = {}
assert_eq(path.kind(file, stat_cache), "file", "kind should identify files")
assert_eq(path.kind(dir, stat_cache), "directory", "kind should identify directories")
assert_eq(path.kind(temp_path("missing.lua"), stat_cache), "missing", "kind should identify missing paths")
assert_eq(path.kind("https://example.com/file.lua", stat_cache), nil, "kind should ignore non-local URIs")
local missing_drive_path = path.canonical_absolute(temp_path("missing-drive-path")):gsub("^([A-Za-z]:)/", "%1//")
assert_eq(path.kind(missing_drive_path, stat_cache), "missing", "kind should keep Windows drive paths local")
assert_eq(path.exists(file, stat_cache), true, "exists should accept files")
assert_eq(path.exists(dir, stat_cache), true, "exists should accept directories")
assert_eq(path.exists(temp_path("missing-again.lua"), stat_cache), false, "exists should reject missing paths")
assert_eq(path.is_file(file, stat_cache), true, "is_file should use kind")
assert_eq(path.is_directory(dir, stat_cache), true, "is_directory should use kind")

local old_xdg = vim.env.XDG_DATA_HOME
vim.env.XDG_DATA_HOME = temp_path("xdg-data")
vim.fn.mkdir(vim.fn.stdpath("data"), "p")

local recent_store = vim.fn.stdpath("data") .. "/starter-recent-paths.json"
local recent_file = temp_path("recent", "legacy.txt")
vim.fn.mkdir(vim.fs.dirname(recent_file), "p")
vim.fn.writefile({ "recent" }, recent_file)

local legacy_path = path.canonical_absolute(recent_file):gsub("^([A-Za-z]:)/", "%1//")
vim.fn.writefile({ vim.json.encode({ legacy_path }) }, recent_store)

package.loaded["plugins.mini.visits"] = nil
local visits = require("plugins.mini.visits")
local items = visits.recent_paths_section(5)()

assert_eq(items[1].recent_path, path.canonical_absolute(vim.fs.dirname(recent_file)), "legacy Windows recent file should fold to its project")
assert_eq(items[1].name ~= "There are no recent projects yet", true, "legacy Windows recent path should not fall back to placeholder")

vim.env.XDG_DATA_HOME = old_xdg

vim.fn.delete(tmp_root, "rf")
print("headless path helper checks passed")
