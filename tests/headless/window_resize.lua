local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)

local function assert_true(value, message)
  if not value then
    error(message, 2)
  end
end

local function rect(win)
  local pos = vim.api.nvim_win_get_position(win)

  return {
    row = pos[1],
    col = pos[2],
    width = vim.api.nvim_win_get_width(win),
    height = vim.api.nvim_win_get_height(win),
  }
end

local function sorted_wins(axis)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  table.sort(wins, function(a, b)
    local a_rect = rect(a)
    local b_rect = rect(b)
    if axis == "row" then
      return a_rect.row < b_rect.row
    end
    return a_rect.col < b_rect.col
  end)
  return wins
end

local function reset_columns()
  vim.cmd("silent! only")
  vim.o.splitright = true
  vim.cmd("vsplit")
  vim.cmd("vsplit")
end

local function reset_rows()
  vim.cmd("silent! only")
  vim.o.splitbelow = true
  vim.cmd("split")
  vim.cmd("split")
end

local window = require("util.window")

vim.cmd("enew")

reset_columns()
local columns = sorted_wins("col")
vim.api.nvim_set_current_win(columns[2])
local before = rect(columns[2])
assert_true(window.resize_current_edge("left", 5), "middle window should move left edge")
local after = rect(columns[2])
assert_true(after.col < before.col, "left edge should move left")
assert_true(after.width > before.width, "moving left edge left should expand current window")

reset_columns()
columns = sorted_wins("col")
vim.api.nvim_set_current_win(columns[2])
before = rect(columns[2])
assert_true(window.resize_current_edge("right", 5), "middle window should move right edge")
after = rect(columns[2])
assert_true(after.col == before.col, "right edge move should keep left edge stable")
assert_true(after.width > before.width, "moving right edge right should expand current window")

reset_columns()
columns = sorted_wins("col")
vim.api.nvim_set_current_win(columns[3])
before = rect(columns[3])
assert_true(window.resize_current_edge("right", 5), "rightmost window should move left edge right")
after = rect(columns[3])
assert_true(after.col > before.col, "rightmost window left edge should move right")
assert_true(after.width < before.width, "moving the only inner edge right should shrink current window")

reset_rows()
local rows = sorted_wins("row")
vim.api.nvim_set_current_win(rows[2])
before = rect(rows[2])
assert_true(window.resize_current_edge("up", 3), "middle window should move top edge up")
after = rect(rows[2])
assert_true(after.row < before.row, "top edge should move up")
assert_true(after.height > before.height, "moving top edge up should expand current window")

reset_rows()
rows = sorted_wins("row")
vim.api.nvim_set_current_win(rows[2])
before = rect(rows[2])
assert_true(window.resize_current_edge("down", 3), "middle window should move bottom edge down")
after = rect(rows[2])
assert_true(after.row == before.row, "bottom edge move should keep top edge stable")
assert_true(after.height > before.height, "moving bottom edge down should expand current window")

reset_rows()
rows = sorted_wins("row")
vim.api.nvim_set_current_win(rows[3])
before = rect(rows[3])
assert_true(window.resize_current_edge("down", 3), "bottom window should move top edge down")
after = rect(rows[3])
assert_true(after.row > before.row, "bottom window top edge should move down")
assert_true(after.height < before.height, "moving the only inner edge down should shrink current window")

vim.cmd("silent! only")
assert_true(not window.resize_current_edge("left", 3), "single window should not resize horizontally")
assert_true(not window.resize_current_edge("up", 3), "single window should not resize vertically")

print("headless window resize checks passed")
