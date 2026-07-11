local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual: %s", message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function assert_deep_eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(string.format("%s\nexpected: %s\nactual: %s", message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

vim.o.autowriteall = true
require("config.options")
assert_eq(vim.o.autowriteall, false, "auto-save.nvim should be the only automatic write owner")

local auto_save_spec = require("plugins.auto-save")
local opts = auto_save_spec.opts
assert_deep_eq(opts.trigger_events.immediate_save, { "BufLeave", "FocusLost", "VimLeavePre" }, "auto-save immediate events should stay explicit")
assert_deep_eq(opts.trigger_events.defer_save, { "InsertLeave" }, "auto-save should defer only after leaving insert mode")
assert_deep_eq(opts.trigger_events.cancel_deferred_save, { "InsertEnter" }, "auto-save should cancel pending writes when editing resumes")

print("headless autosave policy checks passed")
