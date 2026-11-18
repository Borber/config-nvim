local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/mini.nvim")
vim.opt.updatecount = 0
require("plugins.mini.trailspace").setup()

local tmp_root = vim.fn.tempname()
vim.fn.mkdir(tmp_root, "p")

local cases = {
  {
    filename = "note.md",
    filetype = "markdown",
    lines = { "first line  ", "second line", "", "" },
    expected = { "first line  ", "second line", "", "" },
  },
  {
    filename = "code.lua",
    filetype = "lua",
    lines = { "local value = 1  ", "", "" },
    expected = { "local value = 1" },
  },
}

local ok, err = xpcall(function()
  for _, case in ipairs(cases) do
    local path = tmp_root .. "/" .. case.filename
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    vim.bo.filetype = case.filetype
    vim.api.nvim_buf_set_lines(0, 0, -1, false, case.lines)
    vim.cmd("silent write")
    local actual = vim.fn.readfile(path)
    assert(vim.deep_equal(actual, case.expected), case.filename .. ": unexpected saved content: " .. vim.inspect(actual))
    vim.cmd("bdelete")
  end
end, debug.traceback)

vim.fn.delete(tmp_root, "rf")
if not ok then
  error(err, 0)
end
print("headless save cleanup checks passed")
