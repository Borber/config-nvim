-- toggleterm.nvim：原生 Lua API + 临时替换 ui.open_split 自定义布局。
-- 目标布局：
--   * horizontal 终端全部在底部一条横条里，内部左右切分
--   * vertical 终端全部在右侧一条竖条里，内部上下切分
--   * h 横条贴编辑器底部、全宽；v 竖条在右，**底部让位给 h**（即 v 只占 content 区的高度）
-- 实现：开新终端时临时把 `ui.open_split` 替换成自己的 `custom_open_split`，它：
--   - 有同方向终端：跳到那个终端窗口 `rightbelow vsplit` / `rightbelow split`
--   - 无同方向 h：`botright split`（贴底、全宽，自动压在 v 下方）
--   - 无同方向 v：找一个 content（非终端）窗口 `rightbelow vsplit`，新 v 被限制
--     在 content 列里，不会侵入 h 的横条
--   完全不 `close()` / `open()` 任何现有终端，所以现有终端的窗口位置、buffer 内
--   容、滚动位置都不会被触动。

local api = vim.api

local function terminal_mod()
  return require("toggleterm.terminal")
end

--- 仿 ui.lua 里的 local create_term_buf_if_needed：把 term 的 buffer 塞进当前窗口。
local function attach_term_buf(term)
  local win = api.nvim_get_current_win()
  local bufnr = (term.bufnr and api.nvim_buf_is_valid(term.bufnr))
    and term.bufnr
    or api.nvim_create_buf(false, false)
  api.nvim_win_set_buf(win, bufnr)
  term.window, term.bufnr = win, bufnr
  if term.__set_options then term:__set_options() end
  api.nvim_set_current_buf(bufnr)
end

local function find_same_direction_open_win(direction)
  for _, t in ipairs(terminal_mod().get_all(false)) do
    if t:is_open() and t.direction == direction and t.window
      and api.nvim_win_is_valid(t.window) then
      return t.window
    end
  end
end

local function find_content_window()
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    local buf = api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype ~= "terminal" then
      return win
    end
  end
end

--- 自定义 open_split，替换 ui.open_split 使用。
local function custom_open_split(size, term)
  local ui = require("toggleterm.ui")
  local same_win = find_same_direction_open_win(term.direction)

  if same_win then
    -- 有同方向终端：在它里面切一刀
    local cfg_ok, config = pcall(require, "toggleterm.config")
    if cfg_ok and config.get("persist_size") and ui.save_window_size then
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
    local cw = find_content_window()
    if cw then
      api.nvim_set_current_win(cw)
      vim.cmd("rightbelow vsplit")
    else
      vim.cmd("botright vsplit")
    end
  end

  ui.resize_split(term, size)
  attach_term_buf(term)
end

local function open_new(direction)
  return function()
    local ui = require("toggleterm.ui")
    local orig = ui.open_split
    ui.open_split = custom_open_split
    local ok, err = pcall(function()
      terminal_mod().Terminal:new({ direction = direction }):open()
    end)
    ui.open_split = orig
    if not ok then error(err) end
  end
end

local function current_term()
  local _, term = terminal_mod().identify()
  return term
end

local function hide_current()
  local term = current_term()
  if term == nil then
    vim.notify("Not in a terminal", vim.log.levels.INFO)
    return
  end
  term:close()
end

local function shutdown_current()
  local term = current_term()
  if term == nil then
    vim.notify("Not in a terminal", vim.log.levels.INFO)
    return
  end
  term:shutdown()
end

local function rename_terminal()
  vim.cmd.ToggleTermSetName()
end

local function pick_terminal()
  local terms = terminal_mod().get_all(true)
  if #terms == 0 then
    vim.notify("No terminals; use <localleader>th or <localleader>tv to create one", vim.log.levels.INFO)
    return
  end

  local has_telescope, pickers = pcall(require, "telescope.pickers")
  if not has_telescope then
    vim.cmd.TermSelect()
    return
  end

  local finders      = require("telescope.finders")
  local conf         = require("telescope.config").values
  local actions      = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local themes       = require("telescope.themes")

  pickers.new(themes.get_dropdown({
    prompt_title  = "Terminals",
    previewer     = false,
    layout_config = { width = 0.5, height = 0.45 },
  }), {
    finder = finders.new_table({
      results = terms,
      entry_maker = function(term)
        local name    = term:_display_name()
        local state   = term:is_open() and "open" or "hidden"
        local dir     = term.direction or "?"
        local display = string.format("%d  %-24s  [%s, %s]", term.id, name, dir, state)
        return {
          value   = term,
          display = display,
          ordinal = tostring(term.id) .. " " .. name .. " " .. dir,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(bufnr, map)
      local function open_selected()
        local entry = action_state.get_selected_entry()
        actions.close(bufnr)
        if entry and entry.value then
          -- 被选中的终端如果当前是 hidden，也按相同布局规则打开
          local ui = require("toggleterm.ui")
          local orig = ui.open_split
          ui.open_split = custom_open_split
          pcall(function() entry.value:open() end)
          ui.open_split = orig
        end
      end

      local function shutdown_selected()
        local entry = action_state.get_selected_entry()
        if entry and entry.value then
          entry.value:shutdown()
          actions.close(bufnr)
          vim.schedule(pick_terminal)
        end
      end

      actions.select_default:replace(open_selected)
      map({ "i", "n" }, "<C-x>", shutdown_selected)
      return true
    end,
  }):find()
end

return {
  "akinsho/toggleterm.nvim",
  version      = "*",
  dependencies = { "nvim-telescope/telescope.nvim" },
  cmd          = { "ToggleTerm", "TermExec", "TermSelect", "ToggleTermSetName" },
  keys = {
    { "<localleader>th", open_new("horizontal"), desc = "New terminal (horizontal)", mode = { "n", "t" } },
    { "<localleader>tv", open_new("vertical"),   desc = "New terminal (vertical)",   mode = { "n", "t" } },
    { "<localleader>to", pick_terminal,          desc = "Pick terminal",             mode = { "n", "t" } },
    { "<C-x>",           hide_current,           desc = "Hide current terminal",     mode = { "t" } },
    { "<C-S-x>",         shutdown_current,       desc = "Shutdown current terminal", mode = { "t" } },
    { "<localleader>tr", rename_terminal,        desc = "Rename terminal",           mode = { "n", "t" } },
  },
  opts = {
    size = function(term)
      if term.direction == "horizontal" then
        return math.max(12, math.floor(vim.o.lines * 0.3))
      end
      if term.direction == "vertical" then
        return math.max(30, math.floor(vim.o.columns * 0.3))
      end
    end,
    shade_terminals = false,
    persist_mode    = false,
    persist_size    = true,
    start_in_insert = true,
    auto_scroll     = true,
    hide_numbers    = true,
    insert_mappings = false,
    close_on_exit   = false,
    on_open         = function() vim.cmd("startinsert") end,
  },
}
