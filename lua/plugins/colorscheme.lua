return {
  "rose-pine/neovim",
  name = "rose-pine",
  lazy = false,
  priority = 1000,
  config = function()
    local float = require("util.float")

    local function apply_highlights()
      float.apply_highlights()
      vim.api.nvim_set_hl(0, "CursorLineNr", { fg = "#286983", bold = true })
    end

    require("rose-pine").setup({
      variant = "dawn",
      dark_variant = "dawn",
      extend_background_behind_borders = true,
      styles = {
        transparency = false,
      },
    })

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ConfigThemeAppearance", { clear = true }),
      callback = apply_highlights,
    })

    vim.cmd("colorscheme rose-pine-dawn")
  end,
}
