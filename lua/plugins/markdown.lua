return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
  },
  ft = { "markdown" },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    restart_highlighter = true,
    heading = {
      sign = false,
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
    },
    code = {
      sign = false,
      style = "full",
      border = "thin",
      left_pad = 1,
      right_pad = 1,
      language_pad = 1,
    },
    bullet = {
      icons = { "●", "○", "◆", "◇" },
    },
    pipe_table = {
      preset = "round",
    },
    completions = {
      lsp = { enabled = true },
    },
  },
}
