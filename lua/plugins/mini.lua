return {
  "nvim-mini/mini.nvim",
  config = function()
    require("mini.pairs").setup()
    require("plugins.mini.files").setup()
    require("plugins.mini.starter").setup()
  end,
}
