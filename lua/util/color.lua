local M = {}

function M.blend_hex(fg, bg, alpha)
  local function channel(hex, start)
    return tonumber(hex:sub(start, start + 1), 16) or 0
  end

  local r = math.floor(channel(fg, 2) * alpha + channel(bg, 2) * (1 - alpha) + 0.5)
  local g = math.floor(channel(fg, 4) * alpha + channel(bg, 4) * (1 - alpha) + 0.5)
  local b = math.floor(channel(fg, 6) * alpha + channel(bg, 6) * (1 - alpha) + 0.5)

  return string.format("#%02x%02x%02x", r, g, b)
end

return M
