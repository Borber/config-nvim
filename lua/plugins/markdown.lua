return {
  {
    "YousefHadder/markdown-plus.nvim",
    ft = { "markdown" },
    opts = {
      -- 关闭 markdown-plus 自带的所有默认 keymap，按需在 ftplugin 里绑定 <Plug>。
      keymaps = { enabled = false },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    ft = { "markdown" },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      restart_highlighter = true,
      render_modes = true,
      anti_conceal = {
        enabled = true,
        disabled_modes = { "n", "v", "V", "c", "t" },
        above = 0,
        below = 0,
      },
      win_options = {
        conceallevel = {
          default = 0,
          rendered = 3,
        },
        concealcursor = {
          default = "",
          rendered = "n",
        },
      },
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
  },
}
