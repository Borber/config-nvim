return {
  "rose-pine/neovim",
  name = "rose-pine",
  lazy = false,
  priority = 1000,
  config = function()
    local float = require("util.float")

    require("rose-pine").setup({
      variant = "dawn",
      dark_variant = "dawn",
      extend_background_behind_borders = true,
      styles = {
        transparency = false,
      },
    })

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ConfigFloatAppearance", { clear = true }),
      callback = float.apply_highlights,
    })

    vim.cmd("colorscheme rose-pine-dawn")
    float.apply_highlights()
  end,
}
