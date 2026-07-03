local function lua_ls_library()
  local path_util = require("libs.path")
  local library = { vim.env.VIMRUNTIME }
  local lazy_root = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")

  if not path_util.is_directory(lazy_root) then
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
