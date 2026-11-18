local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/mini.nvim")
vim.opt.updatecount = 0

local tmp_root = vim.fn.tempname()
vim.fn.mkdir(tmp_root .. "/nested", "p")
vim.fn.writefile({ "local value = 1" }, tmp_root .. "/nested/file.lua")

local records = {}
package.loaded["config.recent_projects"] = {
  open_path = function(path)
    records[#records + 1] = path
  end,
}

local files = require("plugins.mini.files")
local minifiles = require("mini.files")
local function confirmation()
  return vim.fn.maparg("<S-CR>", "n", false, true)
end

local ok, err = xpcall(function()
  files.open(tmp_root)
  assert(vim.tbl_isempty(confirmation()), "ordinary file tree should not install confirmation")
  assert(minifiles.close(), "file tree should close")

  files.open(tmp_root, { confirm = true })
  assert(confirmation().buffer == 1, "Starter confirmation should be buffer-local")
  require("plugins.mini.files.explorer").open_entry()
  assert(#records == 0, "directory navigation should not record any path")
  local selected = minifiles.get_fs_entry().path
  local confirm = confirmation().callback
  confirm()
  assert(records[1] == selected, "confirmation should open the final selection")
  assert(minifiles.get_explorer_state() == nil, "confirmation should close the file tree")
  confirm()
  assert(#records == 1, "closed tree should not accept stale confirmation")

  files.open(tmp_root)
  assert(vim.tbl_isempty(confirmation()), "ordinary reopen should not inherit Starter confirmation")
  minifiles.close()
  files.toggle()
  assert(vim.tbl_isempty(confirmation()), "ordinary toggle should not inherit Starter confirmation")
end, debug.traceback)

minifiles.close()
vim.fn.delete(tmp_root, "rf")
if not ok then
  error(err, 0)
end
print("headless mini.files integration checks passed")
