return {
  "folke/trouble.nvim",
  cmd = "Trouble",
  opts = {
    auto_close = true,
    keys = {
      ["<cr>"] = "jump_close",
    },
    modes = {
      lsp_base = {
        auto_refresh = false,
        follow = false,
        format = "{kind_icon} {text:ts} {pos}",
        pinned = true,
      },
      lsp_references = {
        win = {
          position = "right",
          size = 0.45,
        },
      },
      lsp_implementations = {
        win = {
          position = "right",
          size = 0.45,
        },
      },
      diagnostics = {
        format = "{severity_icon} {message:md} {pos}",
        win = {
          position = "bottom",
          size = 0.3,
        },
      },
    },
  },
}