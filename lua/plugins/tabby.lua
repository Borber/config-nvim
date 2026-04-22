return {
  "nanozuki/tabby.nvim",
  lazy = false,
  init = function()
    vim.o.showtabline = 2
  end,
  opts = {
    preset = "tab_only",
    option = {
      nerdfont = true,
      buf_name = {
        mode = "unique",
      },
    },
  },
}
