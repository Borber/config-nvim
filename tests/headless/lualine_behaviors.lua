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

local function write_file(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local ok = vim.fn.writefile(lines or { "x" }, path)
  assert_eq(ok, 0, "writefile should succeed: " .. path)
end

local refreshes = 0
local branch_probe_bufs = {}

package.loaded["lualine"] = {
  setup = function() end,
  refresh = function()
    refreshes = refreshes + 1
  end,
}

package.loaded["lualine.components.branch.git_branch"] = {
  find_git_dir = function()
    table.insert(branch_probe_bufs, vim.api.nvim_get_current_buf())
  end,
}

require("plugins.lualine").config(nil, {})

local project = temp_path("project")
vim.fn.mkdir(project, "p")
vim.cmd("silent edit " .. vim.fn.fnameescape(project))
local directory_buf = vim.api.nvim_get_current_buf()

vim.api.nvim_exec_autocmds("User", {
  pattern = "ConfigFilePost",
  modeline = false,
  data = { buf = directory_buf },
})

vim.wait(100, function()
  return refreshes > 0
end)
assert_eq(refreshes, 0, "directory placeholder should not trigger branch refresh")
assert_eq(#branch_probe_bufs, 0, "directory placeholder should not probe git branch")

local file = vim.fs.joinpath(project, "main.lua")
write_file(file, { "print('ok')" })
vim.cmd("silent edit " .. vim.fn.fnameescape(file))
local file_buf = vim.api.nvim_get_current_buf()

vim.api.nvim_exec_autocmds("User", {
  pattern = "ConfigFilePost",
  modeline = false,
  data = { buf = file_buf },
})

vim.wait(100, function()
  return refreshes == 1
end)
assert_eq(refreshes, 1, "real file should refresh lualine branch once")
assert_eq(branch_probe_bufs[1], file_buf, "branch refresh should run in the real file buffer")

vim.fn.delete(tmp_root, "rf")
print("headless lualine behavior checks passed")
