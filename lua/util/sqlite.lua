local M = {}

function M.configure_clib()
  -- Windows 上 sqlite.lua 需要显式找到 dll；Scoop 路径只在未配置时作为本机默认值。
  if vim.g.sqlite_clib_path ~= nil or vim.fn.has("win32") == 0 then
    return
  end

  vim.g.sqlite_clib_path = vim.fn.expand("~/scoop/apps/sqlite-dll/current/sqlite3.dll")
end

return M
