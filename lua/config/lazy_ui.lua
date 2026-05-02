local M = {}

local left_sep = vim.fn.nr2char(0xe0ba)
local right_sep = vim.fn.nr2char(0xe0bc)

local function mode_title(mode, active)
  if mode.name == "home" and active then
    return "lazy.nvim " .. require("lazy.core.config").options.ui.icons.lazy
  end

  return mode.name:sub(1, 1):upper() .. mode.name:sub(2)
end

local function tab_width(mode, active)
  local title = mode_title(mode, active)
  local key = mode.name == "home" and active and "" or " (" .. mode.key .. ")"
  return vim.fn.strdisplaywidth(left_sep .. " " .. title .. key .. " " .. right_sep)
end

local function line_width(render)
  local line = render._lines[#render._lines]
  if line == nil then
    return 0
  end

  local width = 0
  for _, segment in ipairs(line) do
    width = width + vim.fn.strdisplaywidth(segment.str)
  end
  return width
end

local function append_tab(render, mode, active, first)
  local width = line_width(render)
  local gap = first and 0 or 1

  if width > 0 and width + gap + tab_width(mode, active) + render.padding > render.wrap then
    render:nl()
    first = true
  end

  if not first then
    render:append(" ")
  end

  local body = active and "LazyTabActive" or "LazyTab"
  local key = active and "LazyTabActiveKey" or "LazyTabKey"
  local sep = active and "LazyTabActiveSep" or "LazyTabSep"

  render:append(left_sep, sep)
  render:append(" " .. mode_title(mode, active), body)
  if not (mode.name == "home" and active) then
    render:append(" (", body)
    render:append(mode.key, key)
    render:append(")", body)
  end
  render:append(" ", body)
  render:append(right_sep, sep)
end

function M.setup()
  local Config = require("lazy.core.config")
  local Render = require("lazy.view.render")
  local ViewConfig = require("lazy.view.config")

  -- lazy.nvim 只暴露 pill 开关；这里局部替换标题栏渲染，让 Lazy tab 贴近 lualine 的斜角块。
  Render._config_default_title = Render._config_default_title or Render.title
  Render.title = function(render)
    render:nl()

    local modes = vim.tbl_filter(function(command)
      return command.button
    end, ViewConfig.get_commands())

    if Config.options.ui.pills then
      render:nl()
      for index, mode in ipairs(modes) do
        append_tab(render, mode, render.view.state.mode == mode.name, index == 1)
      end
      render:nl()
    end

    if render.progress.done < render.progress.total then
      render:progressbar()
    end
  end
end

return M
