local function read_local_options()
  local ok, local_config = pcall(require, "config.local")
  if not ok or type(local_config) ~= "table" or type(local_config.input_method) ~= "table" then
    return {}
  end

  return local_config.input_method
end

local function usable(command, args)
  if vim.fn.executable(command) ~= 1 then
    return false
  end
  vim.fn.system(vim.list_extend({ command }, args or {}))
  return vim.v.shell_error == 0
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

local function has_value(value)
  return type(value) == "string" and value ~= ""
end

local has_cached_options = false
local cached_options = nil

local function input_method_options()
  if has_cached_options then
    return cached_options
  end

  has_cached_options = true

  local local_options = read_local_options()
  if local_options.enabled == false then
    return nil
  end

  local defaults = {}
  if not (has_value(local_options.default_command) and has_value(local_options.default_im_select)) then
    defaults = detected_options() or {}
  end
  local options = vim.tbl_deep_extend("force", {
    set_default_events = { "VimEnter", "FocusGained", "InsertLeave", "CmdlineLeave" },
    set_previous_events = { "InsertEnter" },
    async_switch_im = true,
  }, defaults, vim.deepcopy(local_options))
  options.enabled = nil

  if not has_value(options.default_command) or not has_value(options.default_im_select) then
    return nil
  end

  cached_options = options
  return cached_options
end

return {
  "keaising/im-select.nvim",
  lazy = false,
  cond = function()
    return input_method_options() ~= nil
  end,
  opts = input_method_options,
  config = function(_, opts)
    require("im_select").setup(opts)
  end,
}
