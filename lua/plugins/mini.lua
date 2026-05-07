return {
  "nvim-mini/mini.nvim",
  lazy = false,
  priority = 900,
  config = function()
    require("plugins.mini.bootstrap").setup()
  end,
}
