local M = {}
local configured = false

local function is_writable_normal_buffer(bufnr)
  if not bufnr or bufnr == 0 or not vim.api.nvim_buf_is_valid(bufnr) then
    return false
  end

  local bo = vim.bo[bufnr]
  return bo.buftype == "" and bo.modifiable and not bo.readonly
end

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
      if not is_writable_normal_buffer(event.buf) then
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
