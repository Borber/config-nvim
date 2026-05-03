local M = {}
local api = vim.api

local function current_filetype()
  return vim.bo[api.nvim_get_current_buf()].filetype
end

local function normal_window_count()
  local count = 0

  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if api.nvim_win_get_config(win).relative == "" then
      count = count + 1
    end
  end

  return count
end

local function is_normal_window(win)
  return api.nvim_win_is_valid(win) and api.nvim_win_get_config(win).relative == ""
end

local function window_rect(win)
  local pos = api.nvim_win_get_position(win)
  local row = pos[1]
  local col = pos[2]

  return {
    row = row,
    col = col,
    bottom = row + api.nvim_win_get_height(win),
    right = col + api.nvim_win_get_width(win),
  }
end

local function ranges_overlap(a_start, a_end, b_start, b_end)
  return a_start < b_end and b_start < a_end
end

local function directional_neighbor(win, direction)
  local current = window_rect(win)
  local best_win
  local best_distance

  for _, candidate in ipairs(api.nvim_tabpage_list_wins(0)) do
    if candidate ~= win and is_normal_window(candidate) then
      local other = window_rect(candidate)
      local distance

      if
        direction == "left"
        and other.col < current.col
        and ranges_overlap(current.row, current.bottom, other.row, other.bottom)
      then
        distance = current.col - other.col
      elseif
        direction == "right"
        and other.col > current.col
        and ranges_overlap(current.row, current.bottom, other.row, other.bottom)
      then
        distance = other.col - current.col
      elseif
        direction == "up"
        and other.row < current.row
        and ranges_overlap(current.col, current.right, other.col, other.right)
      then
        distance = current.row - other.row
      elseif
        direction == "down"
        and other.row > current.row
        and ranges_overlap(current.col, current.right, other.col, other.right)
      then
        distance = other.row - current.row
      end

      if distance ~= nil and (best_distance == nil or distance < best_distance) then
        best_win = candidate
        best_distance = distance
      end
    end
  end

  return best_win
end

local function resize_width(win, amount)
  if win == nil or not is_normal_window(win) then
    return false
  end

  return pcall(api.nvim_win_set_width, win, math.max(1, api.nvim_win_get_width(win) + amount))
end

local function resize_height(win, amount)
  if win == nil or not is_normal_window(win) then
    return false
  end

  return pcall(api.nvim_win_set_height, win, math.max(1, api.nvim_win_get_height(win) + amount))
end

local function notify_close_failure(target, err)
  vim.notify("Failed to close " .. target .. ": " .. tostring(err), vim.log.levels.WARN)
end

local function close_mini_files(ft)
  if ft ~= "minifiles" and ft ~= "minifiles-help" then
    return false
  end

  local minifiles = package.loaded["mini.files"]
  if minifiles == nil or type(minifiles.close) ~= "function" then
    return false
  end

  return minifiles.close() ~= false
end

local function close_diffview()
  local lib = package.loaded["diffview.lib"]
  if lib == nil or type(lib.get_current_view) ~= "function" or lib.get_current_view() == nil then
    return false
  end

  local diffview = package.loaded["diffview"]
  if diffview == nil or type(diffview.close) ~= "function" then
    return false
  end

  diffview.close()
  return true
end

local function close_toggleterm(ft)
  if ft ~= "toggleterm" then
    return false
  end

  local terminal = package.loaded["toggleterm.terminal"]
  if terminal == nil or type(terminal.identify) ~= "function" then
    return false
  end

  local _, term = terminal.identify()
  if term == nil or type(term.close) ~= "function" then
    return false
  end

  term:close()
  return true
end

local function close_float_window()
  local win = api.nvim_get_current_win()

  if api.nvim_win_get_config(win).relative ~= "" then
    local ok, err = pcall(api.nvim_win_close, win, false)
    if not ok then
      notify_close_failure("window", err)
    end
    return ok
  end

  return false
end

local function close_tab()
  if #api.nvim_list_tabpages() > 1 then
    local ok, err = pcall(vim.cmd.tabclose)
    if not ok then
      notify_close_failure("tab", err)
    end
    return ok
  end

  return false
end

local function close_split_window()
  if normal_window_count() <= 1 then
    return false
  end

  local ok, err = pcall(api.nvim_win_close, api.nvim_get_current_win(), false)
  if not ok then
    notify_close_failure("window", err)
  end

  return ok
end

local function close_buffer()
  if vim.bo[api.nvim_get_current_buf()].buftype ~= "" then
    return false
  end

  local ok, bufremove = pcall(require, "mini.bufremove")
  if not ok or type(bufremove.delete) ~= "function" then
    local fallback_ok, err = pcall(vim.cmd.bdelete)
    if not fallback_ok then
      notify_close_failure("buffer", err)
    end
    return fallback_ok
  end

  local delete_ok, err = pcall(bufremove.delete, 0, false)
  if not delete_ok then
    notify_close_failure("buffer", err)
  end

  return delete_ok
end

function M.close_current()
  local ft = current_filetype()

  -- 先交给拥有整组 UI 的插件清理，再按容器层级从外到内关闭。
  if close_mini_files(ft) or close_diffview() or close_toggleterm(ft) then
    return true
  end

  return close_float_window() or close_split_window() or close_tab() or close_buffer()
end

function M.resize_current_edge(direction, amount)
  amount = amount or 2

  local current = api.nvim_get_current_win()
  if not is_normal_window(current) then
    return false
  end

  if direction == "right" then
    local right = directional_neighbor(current, "right")
    if right ~= nil then
      return resize_width(current, amount)
    end
    return resize_width(directional_neighbor(current, "left"), amount)
  end

  if direction == "left" then
    local left = directional_neighbor(current, "left")
    if left ~= nil then
      return resize_width(left, -amount)
    end
    if directional_neighbor(current, "right") ~= nil then
      return resize_width(current, -amount)
    end
    return false
  end

  if direction == "down" then
    local down = directional_neighbor(current, "down")
    if down ~= nil then
      return resize_height(current, amount)
    end
    return resize_height(directional_neighbor(current, "up"), amount)
  end

  if direction == "up" then
    local up = directional_neighbor(current, "up")
    if up ~= nil then
      return resize_height(up, -amount)
    end
    if directional_neighbor(current, "down") ~= nil then
      return resize_height(current, -amount)
    end
    return false
  end

  return false
end

return M
