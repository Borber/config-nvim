return {
  "sainnhe/everforest",
  lazy = false,
  priority = 1000,
  config = function()
    local float = require("util.float")
    local everforest = require("util.palette").everforest

    local function apply_highlights()
      float.apply_highlights()
      vim.api.nvim_set_hl(0, "LspInlayHint", { fg = everforest.muted, bg = "NONE", italic = true })
    end

    vim.o.background = "dark"
    vim.g.everforest_background = "hard"
    vim.g.everforest_better_performance = 1
    vim.g.everforest_enable_italic = 1
    vim.g.everforest_inlay_hints_background = "none"
    vim.g.everforest_transparent_background = 1

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ConfigThemeAppearance", { clear = true }),
      pattern = "everforest",
      callback = apply_highlights,
    })

    vim.cmd.colorscheme("everforest")
  end,
}
