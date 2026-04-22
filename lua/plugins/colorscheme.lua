return {
  "rose-pine/neovim",
  name = "rose-pine",
  lazy = false,
  priority = 1000,
  config = function()
    require("rose-pine").setup({
      variant = "dawn",
      dark_variant = "dawn",
      extend_background_behind_borders = true,
      styles = {
        transparency = false,
      },
    })

    vim.cmd("colorscheme rose-pine-dawn")
  end,
}
