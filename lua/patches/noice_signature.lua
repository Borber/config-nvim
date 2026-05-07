-- ============================================
-- noice signature guard
-- ============================================
local M = {}

local function default_blink_menu_visible()
  local blink = package.loaded["blink.cmp"]
  return blink ~= nil and blink.is_menu_visible ~= nil and blink.is_menu_visible()
end

function M.apply(blink_menu_visible)
  blink_menu_visible = blink_menu_visible or default_blink_menu_visible

  local signature = require("noice.lsp.signature")
  if rawget(signature, "_config_nvim_blink_guarded") then
    return signature
  end

  local original_check = signature.check
  local original_on_signature = signature.on_signature

  signature.check = function(...)
    if blink_menu_visible() then
      return
    end

    return original_check(...)
  end

  signature.on_signature = function(...)
    if blink_menu_visible() then
      return
    end

    return original_on_signature(...)
  end

  rawset(signature, "_config_nvim_blink_guarded", true)
  return signature
end

return M
