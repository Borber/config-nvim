local M = {}
local configured = false

local buffer_util = require("util.buffer")

function M.setup()
  if configured then
    return
  end

  configured = true

  local trailspace = require("mini.trailspace")
  trailspace.setup()

  vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("ConfigMiniTrailspace", { clear = true }),
    callback = function(event)
      if buffer_util.normal_writable(event.buf) == nil then
        return
      end

      -- mini.trailspace 操作当前 buffer，这里显式切到触发保存的 buffer。
      vim.api.nvim_buf_call(event.buf, function()
        trailspace.trim()
        trailspace.trim_last_lines()
      end)
    end,
    desc = "Trim trailing whitespace before writing files",
  })
end

return M
