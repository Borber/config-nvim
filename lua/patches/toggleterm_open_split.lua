-- ============================================
-- toggleterm open_split patch
-- ============================================
local M = {}
local api = vim.api

local default_terminal

local function terminal_mod()
  return require("toggleterm.terminal")
end

-- ============================================
-- split 布局辅助
-- ============================================
function M.attach_term_buf(term)
  -- 仿 ui.lua 里的 local create_term_buf_if_needed：把 term 的 buffer 塞进当前窗口。
  local win = api.nvim_get_current_win()
  local bufnr = (term.bufnr and api.nvim_buf_is_valid(term.bufnr)) and term.bufnr or api.nvim_create_buf(false, false)
  api.nvim_win_set_buf(win, bufnr)
  term.window, term.bufnr = win, bufnr
  if term.__set_options then
    term:__set_options()
  end
  api.nvim_set_current_buf(bufnr)
end

function M.find_same_direction_open_win(direction)
  -- 同方向终端共享同一块区域：水平终端横向分列，垂直终端纵向分行。
  for _, term in ipairs(terminal_mod().get_all(false)) do
    if term:is_open() and term.direction == direction and term.window and api.nvim_win_is_valid(term.window) then
      return term.window
    end
  end
end

function M.find_content_window()
  -- content 窗口指普通编辑窗口；新建 vertical 终端时优先从这里切分，
  -- 这样不会把底部 horizontal 终端区域也劈开。
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    local buf = api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype ~= "terminal" then
      return win
    end
  end
end

function M.custom_open_split(size, term)
  local ui = require("toggleterm.ui")
  local same_win = M.find_same_direction_open_win(term.direction)

  if same_win then
    -- 有同方向终端：在它里面切一刀
    local config = require("toggleterm.config")
    if config.get("persist_size") and ui.save_window_size then
      ui.save_window_size(term.direction, same_win)
    end
    api.nvim_set_current_win(same_win)
    if term.direction == "horizontal" then
      vim.cmd("rightbelow vsplit")
    else
      vim.cmd("rightbelow split")
    end
  elseif term.direction == "horizontal" then
    -- 无 h：贴底全宽
    vim.cmd("botright split")
  else
    -- 无 v：只切 content 区，不碰已有 h 横条
    local content_win = M.find_content_window()
    if content_win then
      api.nvim_set_current_win(content_win)
      vim.cmd("rightbelow vsplit")
    else
      vim.cmd("botright vsplit")
    end
  end

  ui.resize_split(term, size)
  M.attach_term_buf(term)
end

function M.with_custom_open_split(callback)
  local ui = require("toggleterm.ui")
  local original = ui.open_split
  ui.open_split = M.custom_open_split
  local ok, err = pcall(callback)
  ui.open_split = original
  if not ok then
    error(err)
  end
end

-- ============================================
-- 对外终端入口
-- ============================================
function M.open_new(direction)
  return function()
    M.with_custom_open_split(function()
      terminal_mod().Terminal:new({ direction = direction }):open()
    end)
  end
end

function M.toggle_default()
  default_terminal = default_terminal or terminal_mod().Terminal:new({ direction = "horizontal" })
  M.with_custom_open_split(function()
    default_terminal:toggle()
  end)
end

function M.rename_terminal()
  vim.cmd.ToggleTermSetName()
end

function M.pick_terminal()
  local terms = terminal_mod().get_all(true)
  if #terms == 0 then
    vim.notify("No terminals; create one with <leader>th or <leader>tv", vim.log.levels.INFO)
    return
  end

  -- 终端选择器复用通用 Telescope 外壳，但保留 toggleterm 自己的打开/聚焦动作。
  require("util.telescope_picker").dropdown({
    prompt_title = "Terminals",
    layout_config = { width = 0.5, height = 0.45 },
    results = terms,
    entry_maker = function(term)
      local name = term:_display_name()
      local state = term:is_open() and "open" or "hidden"
      local dir = term.direction or "?"
      local display = string.format("%d  %-24s  [%s, %s]", term.id, name, dir, state)
      return {
        value = term,
        display = display,
        ordinal = tostring(term.id) .. " " .. name .. " " .. dir,
      }
    end,
    attach_mappings = function(bufnr, map, telescope)
      local function open_selected()
        local entry = telescope.action_state.get_selected_entry()
        telescope.actions.close(bufnr)
        if entry and entry.value then
          -- 被选中的终端如果当前是 hidden，也按相同布局规则打开
          M.with_custom_open_split(function()
            entry.value:open()
          end)
        end
      end

      telescope.actions.select_default:replace(open_selected)
      return true
    end,
  })
end

return M
