-- ============================================
-- fzf-lua Picker 通用封装
-- 提供符合 vim.ui.select 协议的 picker，
-- 供 Overseer / ToggleTerm / Yanky 等模块复用。
-- ============================================
local M = {}

local delimiter = "\t"

local function display_lines(items, format_item)
  local lines = {}

  for index, item in ipairs(items) do
    lines[index] = tostring(index) .. delimiter .. format_item(item)
  end

  return lines
end

local function selected_index(selected)
  local line = selected and selected[1]
  if type(line) ~= "string" then
    return nil
  end

  return tonumber(line:match("^(%d+)" .. delimiter))
end

local function hidden_index_opts(extra)
  return vim.tbl_extend("force", {
    ["--delimiter"] = delimiter,
    ["--nth"] = "2..",
    ["--with-nth"] = "2..",
    ["--no-multi"] = "",
  }, extra or {})
end

local function winopts(opts)
  return vim.tbl_extend("force", {
    width = 0.65,
    height = 0.5,
    backdrop = false,
    preview = { hidden = "hidden" },
  }, opts or {})
end

function M.select(items, opts, on_choice, picker_opts)
  opts = opts or {}
  picker_opts = picker_opts or {}

  local format_item = opts.format_item or tostring
  local lines = display_lines(items, format_item)

  require("fzf-lua").fzf_exec(lines, {
    prompt = (opts.prompt or "Select") .. "> ",
    winopts = winopts(picker_opts.winopts),
    fzf_opts = hidden_index_opts(picker_opts.fzf_opts),
    actions = {
      ["default"] = function(selected)
        local index = selected_index(selected)
        if index ~= nil and items[index] ~= nil then
          on_choice(items[index], index)
        else
          on_choice(nil)
        end
      end,
      ["esc"] = function()
        on_choice(nil)
      end,
      ["ctrl-c"] = function()
        on_choice(nil)
      end,
    },
  })

  return true
end

return M
