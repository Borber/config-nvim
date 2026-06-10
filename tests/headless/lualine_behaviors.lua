local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)

local tmp_root = vim.fn.tempname()
vim.fn.delete(tmp_root, "rf")
vim.fn.mkdir(tmp_root, "p")
vim.o.columns = 120

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

local function flush_scheduled()
  local done = false
  vim.defer_fn(function()
    done = true
  end, 10)
  vim.wait(1000, function()
    return done
  end)
end

local refreshes = 0
local branch_probe_bufs = {}
local lualine_opts
local wakatime_jobs = {}
local wakatime_total_seconds = 18840
local original_exepath = vim.fn.exepath
local original_jobstart = vim.fn.jobstart

package.loaded["lualine"] = {
  setup = function(opts)
    lualine_opts = opts
  end,
  refresh = function()
    refreshes = refreshes + 1
  end,
}

rawset(vim.fn, "exepath", function(command)
  return command == "wakatime-cli" and "wakatime-cli" or ""
end)

rawset(vim.fn, "jobstart", function(command, opts)
  table.insert(wakatime_jobs, command)

  opts.on_stdout(1, {
    vim.json.encode({
      data = {
        grand_total = {
          total_seconds = wakatime_total_seconds,
        },
      },
    }),
  }, "stdout")
  opts.on_exit(1, 0, "exit")

  return 1
end)

package.loaded["lualine.components.branch.git_branch"] = {
  find_git_dir = function()
    table.insert(branch_probe_bufs, vim.api.nvim_get_current_buf())
  end,
}

local lualine_spec = require("plugins.lualine")
lualine_spec.config(nil, lualine_spec.opts())
assert_eq(lualine_opts.sections.lualine_c[1][1](), "", "WakaTime component should be empty before refresh")
assert_eq(lualine_opts.sections.lualine_c[1].cond(), false, "WakaTime cond should not load status module")

local project = temp_path("project")
vim.fn.mkdir(project, "p")
vim.cmd("silent edit " .. vim.fn.fnameescape(project))
local directory_buf = vim.api.nvim_get_current_buf()

vim.api.nvim_exec_autocmds("User", {
  pattern = "ConfigFilePost",
  modeline = false,
  data = { buf = directory_buf },
})

flush_scheduled()
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

flush_scheduled()
assert_eq(refreshes, 1, "real file should refresh lualine branch once")
assert_eq(branch_probe_bufs[1], file_buf, "branch refresh should run in the real file buffer")

vim.api.nvim_exec_autocmds("User", {
  pattern = "ConfigUiReady",
  modeline = false,
})
flush_scheduled()
assert_eq(#wakatime_jobs, 0, "ConfigUiReady should not trigger an immediate WakaTime CLI query")

vim.api.nvim_exec_autocmds("FocusGained", { modeline = false })
flush_scheduled()
assert_eq(#wakatime_jobs, 1, "FocusGained should start one WakaTime CLI query")
assert_eq(table.concat(wakatime_jobs[1], " "), "wakatime-cli --today --output raw-json", "WakaTime query should request raw JSON from CLI")
assert_eq(
  lualine_opts.sections.lualine_c[1][1](),
  require("libs.icons").ui.time .. " 314" .. vim.fn.nr2char(0x2032),
  "WakaTime today should render total minutes from JSON seconds"
)
vim.api.nvim_exec_autocmds("BufWritePost", { modeline = false })
vim.api.nvim_exec_autocmds("FocusGained", { modeline = false })
flush_scheduled()
assert_eq(#wakatime_jobs, 1, "WakaTime refresh events should respect the refresh interval")

assert_eq(type(lualine_opts.sections.lualine_c[1].color), "function", "WakaTime should keep its own color block")

wakatime_total_seconds = 0
package.loaded["plugins.lualine.wakatime_status"] = nil
require("plugins.lualine.wakatime_status").setup_refresh()
vim.api.nvim_exec_autocmds("FocusGained", { modeline = false })
flush_scheduled()
assert_eq(#wakatime_jobs, 2, "Zero-minute refresh should still query WakaTime CLI once")
assert_eq(
  lualine_opts.sections.lualine_c[1][1](),
  require("libs.icons").ui.time .. " 0" .. vim.fn.nr2char(0x2032),
  "WakaTime today should still render zero minutes"
)
assert_eq(lualine_opts.sections.lualine_c[1].cond(), true, "WakaTime cond should stay visible at zero minutes when width is enough")

rawset(vim.fn, "exepath", original_exepath)
rawset(vim.fn, "jobstart", original_jobstart)
vim.fn.delete(tmp_root, "rf")
print("headless lualine behavior checks passed")
