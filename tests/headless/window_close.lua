local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual: %s", message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function assert_true(value, message)
  if not value then
    error(message, 2)
  end
end

local window = require("util.window")

vim.cmd("enew")
local original_window_count = #vim.api.nvim_tabpage_list_wins(0)

local old_bufremove = package.loaded["mini.bufremove"]
local deleted_buf
local deleted_force
package.loaded["mini.bufremove"] = {
  delete = function(bufnr, force)
    deleted_buf = bufnr
    deleted_force = force
  end,
}
vim.cmd("vsplit")
assert_true(window.close_current(), "normal split window should close")
assert_eq(deleted_buf, nil, "normal split should close before deleting buffer")
assert_eq(deleted_force, nil, "normal split should not force-delete buffer")
assert_eq(#vim.api.nvim_tabpage_list_wins(0), original_window_count, "normal split should be removed")

vim.cmd("vsplit")
vim.cmd("enew")
vim.bo.buftype = "nofile"
assert_true(window.close_current(), "special scratch window should close")
assert_eq(#vim.api.nvim_tabpage_list_wins(0), original_window_count, "special scratch split should be removed")

local old_minifiles = package.loaded["mini.files"]
local mini_closed = false
package.loaded["mini.files"] = {
  close = function()
    mini_closed = true
    return true
  end,
}
vim.bo.filetype = "minifiles"
assert_true(window.close_current(), "mini.files window should report closed")
assert_true(mini_closed, "mini.files close should be delegated")

local old_diffview = package.loaded["diffview"]
local old_diffview_lib = package.loaded["diffview.lib"]
local diffview_closed = false
package.loaded["diffview"] = {
  close = function()
    diffview_closed = true
  end,
}
package.loaded["diffview.lib"] = {
  get_current_view = function()
    return {}
  end,
}
vim.bo.filetype = ""
assert_true(window.close_current(), "Diffview tab should report closed")
assert_true(diffview_closed, "Diffview close should be delegated")
package.loaded["diffview"] = old_diffview
package.loaded["diffview.lib"] = old_diffview_lib

local old_toggleterm = package.loaded["toggleterm.terminal"]
local toggleterm_closed = false
package.loaded["toggleterm.terminal"] = {
  identify = function()
    return nil, {
      close = function()
        toggleterm_closed = true
      end,
    }
  end,
}
vim.bo.filetype = "toggleterm"
assert_true(window.close_current(), "toggleterm window should report closed")
assert_true(toggleterm_closed, "toggleterm close should be delegated")

deleted_buf = nil
deleted_force = nil
vim.bo.filetype = ""
assert_true(window.close_current(), "last normal window should delete the current buffer")
assert_eq(deleted_buf, 0, "buffer fallback should target current buffer")
assert_eq(deleted_force, false, "buffer fallback should not force-delete")

package.loaded["mini.files"] = old_minifiles
package.loaded["mini.bufremove"] = old_bufremove
package.loaded["toggleterm.terminal"] = old_toggleterm

print("headless window close checks passed")
