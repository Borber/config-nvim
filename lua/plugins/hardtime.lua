return {
  "m4xshen/hardtime.nvim",
  lazy = false,
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  keys = {
    { "<leader>kr", "<Cmd>Hardtime report<CR>", desc = "Hardtime report" },
    { "<leader>kt", "<Cmd>Hardtime toggle<CR>", desc = "Toggle Hardtime" },
  },
  opts = {
    -- 先用提示模式观察低效按键习惯，不直接拦截你的按键流。
    restriction_mode = "hint",
    disable_mouse = false,
    disabled_filetypes = {
      starter = true,
    },
  },
}
