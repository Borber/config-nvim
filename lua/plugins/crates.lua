local function map_cargo_lsp_keys(bufnr)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, {
      buffer = bufnr,
      desc = desc,
      silent = true,
    })
  end

  map("K", function()
    vim.lsp.buf.hover({ border = require("util.float").border })
  end, "Crate hover")
  map("<leader>ca", vim.lsp.buf.code_action, "Crate code action")
end

return {
  "Saecki/crates.nvim",
  tag = "stable",
  event = { "BufReadPost Cargo.toml", "BufNewFile Cargo.toml" },
  opts = {
    on_attach = map_cargo_lsp_keys,
    completion = {
      crates = {
        enabled = true,
      },
    },
    lsp = {
      enabled = true,
      actions = true,
      completion = true,
      hover = true,
    },
  },
}
