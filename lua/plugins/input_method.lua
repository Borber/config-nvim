local lifecycle = require("config.lifecycle")

local function read_local_options()
  local ok, local_config = pcall(require, "config.local")
  if not ok or type(local_config) ~= "table" or type(local_config.input_method) ~= "table" then
    return {}
  end

  return local_config.input_method
end

local function executable(command)
  return vim.fn.executable(command) == 1
end

local function command_succeeds(command, args)
  local argv = { command }
  vim.list_extend(argv, args or {})
  vim.fn.system(argv)

  return vim.v.shell_error == 0
end

local function usable(command, args)
  return executable(command) and command_succeeds(command, args)
end

local function detected_options()
  if vim.fn.has("macunix") == 1 then
    if usable("macism") then
      return {
        default_command = "macism",
        default_im_select = "com.apple.keylayout.ABC",
      }
    end

    if usable("im-select") then
      return {
        default_command = "im-select",
        default_im_select = "com.apple.keylayout.ABC",
      }
    end
  end

  if vim.fn.has("linux") == 1 then
    if usable("fcitx5-remote", { "-n" }) then
      return {
        default_command = "fcitx5-remote",
        default_im_select = "keyboard-us",
      }
    end

    if usable("ibus", { "engine" }) then
      return {
        default_command = "ibus",
        default_im_select = "xkb:us::eng",
      }
    end
  end

  return nil
end

-- 检测结果单独缓存：即使上层 options 缓存被清除，也不会重新 fork 子进程。
local detected_defaults = nil
local detected_done = false

local function ensure_detected()
  if not detected_done then
    detected_done = true
    detected_defaults = detected_options()
  end
  return detected_defaults
end

local function has_value(value)
  return type(value) == "string" and value ~= ""
end

local function has_command(value)
  return has_value(value) or (type(value) == "table" and has_value(value[1]))
end

local function has_complete_options(options)
  return has_command(options.default_command) and has_value(options.default_im_select)
end

local function sanitized_options(options)
  local result = vim.deepcopy(options)
  result.enabled = nil

  return result
end

local cached_options = nil
local disabled = false

local function input_method_options(opts)
  opts = opts or {}

  if disabled then
    return nil
  end

  if cached_options ~= nil then
    return cached_options
  end

  local local_options = read_local_options()
  if local_options.enabled == false then
    disabled = true
    return nil
  end

  local defaults = {}
  if opts.detect == true and not has_complete_options(local_options) then
    defaults = ensure_detected() or {}
  end

  local options = vim.tbl_deep_extend("force", {
    set_default_events = { "FocusGained", "InsertLeave", "CmdlineLeave" },
    set_previous_events = { "InsertEnter" },
    async_switch_im = true,
  }, defaults, sanitized_options(local_options))

  if not has_complete_options(options) then
    return nil
  end

  cached_options = options
  return cached_options
end

return {
  "keaising/im-select.nvim",
  event = { lifecycle.lazy_events.background, "InsertEnter" },
  config = function()
    local opts = input_method_options({ detect = true })
    if opts == nil then
      return
    end

    require("im_select").setup(opts)
  end,
}
