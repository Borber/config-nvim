return {
  "nvim-mini/mini.nvim",
  config = function()
    require("plugins.mini.files").setup()
    require("plugins.mini.starter").setup()
  end,
}
