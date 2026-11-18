return {
  cmd = { "taplo", "lsp", "--config", vim.fs.joinpath(vim.fn.stdpath("config"), "taplo.toml"), "stdio" },
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
