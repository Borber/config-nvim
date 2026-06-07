local M = {}

function M.statusline(force)
  local ok, lualine = pcall(require, "lualine")
  if not ok then
    return
  end

  lualine.refresh({
    scope = "tabpage",
    place = { "statusline" },
    trigger = "autocmd",
    force = force == true,
  })
end

return M
