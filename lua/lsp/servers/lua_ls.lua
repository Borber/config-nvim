local path_util = require("libs.path")
local library_cache = nil
local library_cache_token = nil

local function stat_token(path)
  local stat = path_util.stat(path)
  if stat == nil then
    return path .. ":missing"
  end

  local mtime = stat.mtime or {}
  return table.concat({
    path,
    stat.type or "",
    tostring(stat.size or 0),
    tostring(mtime.sec or 0),
    tostring(mtime.nsec or 0),
  }, ":")
end

local function lua_ls_library()
  local lazy_root = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")
  local token = stat_token(lazy_root)

  if library_cache ~= nil and library_cache_token == token then
    return library_cache
  end

  local library = { vim.env.VIMRUNTIME }

  if not path_util.is_directory(lazy_root) then
    library_cache = library
    library_cache_token = token
    return library
  end

  -- LuaLS 需要看到插件源码里的 EmmyLua 注解，才能识别插件导出的模块、类型和全局对象。
  for name, type in vim.fs.dir(lazy_root) do
    if type == "directory" then
      local lua_dir = vim.fs.joinpath(lazy_root, name, "lua")
      if path_util.is_directory(lua_dir) then
        table.insert(library, lua_dir)
      end
    end
  end

  library_cache = library
  library_cache_token = token
  return library
end

return {
  settings = {
    Lua = {
      completion = { callSnippet = "Replace" },
      diagnostics = { globals = { "vim", "MiniIcons" } },
      runtime = { version = "LuaJIT" },
      workspace = {
        checkThirdParty = false,
        library = lua_ls_library(),
      },
    },
  },
}
