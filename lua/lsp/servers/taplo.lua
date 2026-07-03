local function taplo_config()
  return vim.fs.joinpath(vim.fn.stdpath("config"), "taplo.toml")
end

local function taplo_cmd()
  local mason_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "bin", "taplo")
  local config_path = taplo_config()
  if vim.fn.executable("taplo") == 1 then
    return { "taplo", "lsp", "--config", config_path, "stdio" }
  end

  if vim.uv.fs_stat(mason_bin) then
    return { mason_bin, "lsp", "--config", config_path, "stdio" }
  end

  return { "taplo", "lsp", "--config", config_path, "stdio" }
end

return {
  cmd = taplo_cmd(),
  settings = {
    evenBetterToml = {
      completion = {
        maxKeys = 16,
      },
      schema = {
        enabled = true,
      },
    },
  },
}
