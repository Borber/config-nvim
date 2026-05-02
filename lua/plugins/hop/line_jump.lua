local M = {}
local handlers = {}

-- 特殊界面可接管 HopLine 目标；无人处理时 hop.lua 回落到原生移动。
function M.register(handler)
  if type(handler) ~= "function" then
    return
  end

  for _, registered in ipairs(handlers) do
    if registered == handler then
      return
    end
  end

  table.insert(handlers, handler)
end

function M.handle(jump_target)
  for _, handler in ipairs(handlers) do
    if handler(jump_target) then
      return true
    end
  end

  return false
end

return M
