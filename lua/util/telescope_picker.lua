local M = {}

local function load_telescope()
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return nil
  end

  return {
    pickers = pickers,
    finders = require("telescope.finders"),
    config = require("telescope.config").values,
    actions = require("telescope.actions"),
    action_state = require("telescope.actions.state"),
    themes = require("telescope.themes"),
  }
end

function M.dropdown(opts)
  opts = opts or {}

  local telescope = load_telescope()
  if telescope == nil then
    if opts.fallback then
      opts.fallback()
    end

    return false
  end

  local previewer = opts.previewer
  if previewer == nil then
    previewer = false
  end

  telescope.pickers.new(telescope.themes.get_dropdown({
    prompt_title = opts.prompt_title or "Select",
    previewer = previewer,
    layout_config = opts.layout_config or { width = 0.65, height = 0.5 },
  }), {
    finder = telescope.finders.new_table({
      results = opts.results or {},
      entry_maker = opts.entry_maker,
    }),
    sorter = opts.sorter or telescope.config.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      if opts.attach_mappings == nil then
        return true
      end

      local result = opts.attach_mappings(prompt_bufnr, map, telescope)
      return result == nil and true or result
    end,
  }):find()

  return true
end

function M.select(items, opts, on_choice, picker_opts)
  opts = opts or {}
  picker_opts = picker_opts or {}

  local format_item = opts.format_item or tostring
  local entries = vim
    .iter(items)
    :enumerate()
    :map(function(index, item)
      return {
        index = index,
        value = item,
        display = format_item(item),
      }
    end)
    :totable()

  return M.dropdown({
    prompt_title = opts.prompt or "Select",
    layout_config = picker_opts.layout_config,
    results = entries,
    fallback = function()
      local fallback_select = picker_opts.fallback or vim.ui.select
      fallback_select(items, opts, on_choice)
    end,
    entry_maker = function(entry)
      return {
        value = entry.value,
        index = entry.index,
        display = entry.display,
        ordinal = entry.display,
      }
    end,
    attach_mappings = function(prompt_bufnr, map, telescope)
      local function cancel()
        telescope.actions.close(prompt_bufnr)
        on_choice(nil)
      end

      telescope.actions.select_default:replace(function()
        local entry = telescope.action_state.get_selected_entry()
        telescope.actions.close(prompt_bufnr)
        if entry then
          on_choice(entry.value, entry.index)
        else
          on_choice(nil)
        end
      end)
      map({ "i", "n" }, "<Esc>", cancel)
      map({ "i", "n" }, "<C-c>", cancel)
      map("n", "q", cancel)
      return true
    end,
  })
end

return M
