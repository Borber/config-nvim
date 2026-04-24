return {
  "nvim-mini/mini.nvim",
  lazy = false,
  priority = 900,
  config = function()
    -- 图标：作为 nvim-web-devicons 的替代，其它插件通过 mock 自动复用
    require("mini.icons").setup()
    MiniIcons.mock_nvim_web_devicons()

    require("mini.pairs").setup()
    require("mini.ai").setup()
    require("mini.surround").setup()

    require("plugins.mini.visits").setup()
    require("plugins.mini.files").setup()
    require("plugins.mini.starter").setup()
  end,
}
