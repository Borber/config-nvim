local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)
vim.opt.updatecount = 0

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

local function write_file(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local ok = vim.fn.writefile(lines or { "x" }, path)
  assert_eq(ok, 0, "writefile should succeed: " .. path)
end

local function delete_file(path)
  local ok = vim.fn.delete(path)
  assert_eq(ok, 0, "delete should succeed: " .. path)
end

package.loaded["config.local"] = {
  lsp = {
    diagnostic_mute_roots = {},
    diagnostic_mute_markers = {
      ".nvim-disable-lsp-diagnostics",
      ".nvim/lsp-diagnostics-off",
    },
  },
}

local diagnostics = require("plugins.lsp.diagnostics")

local project = temp_path("project")
local file = vim.fs.joinpath(project, "src", "main.lua")
write_file(file, { "print('ok')" })
vim.cmd("silent edit " .. vim.fn.fnameescape(file))

local client = {
  config = {
    root_dir = project,
  },
}

local function muted()
  return diagnostics.muted(0, client)
end

assert_eq(muted(), false, "missing marker should not mute diagnostics")

local nested_marker = vim.fs.joinpath(project, ".nvim", "lsp-diagnostics-off")
write_file(nested_marker, { "" })
assert_eq(muted(), true, "creating nested marker should invalidate cached negative result")

delete_file(nested_marker)
write_file(vim.fs.joinpath(project, ".nvim", ".mtime-bump"), { "bump" })
assert_eq(muted(), false, "deleting nested marker should invalidate cached positive result")

local direct_marker = vim.fs.joinpath(project, ".nvim-disable-lsp-diagnostics")
write_file(direct_marker, { "" })
assert_eq(muted(), true, "creating direct marker should mute diagnostics")

delete_file(direct_marker)
write_file(vim.fs.joinpath(project, ".mtime-bump"), { "bump" })
assert_eq(muted(), false, "deleting direct marker should unmute diagnostics")

vim.fn.delete(tmp_root, "rf")
print("headless lsp diagnostic checks passed")
