return {
  "tris203/hawtkeys.nvim",
  cmd = {
    "Hawtkeys",
    "HawtkeysAll",
    "HawtkeysDupes",
  },
  keys = {
    { "<leader>ka", "<Cmd>HawtkeysAll<CR>", desc = "All keymaps" },
    { "<leader>kd", "<Cmd>HawtkeysDupes<CR>", desc = "Duplicate keymaps" },
    { "<leader>kh", "<Cmd>Hawtkeys<CR>", desc = "Keymap suggestions" },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    -- 让 hawtkeys 也识别 config/keymaps.lua 里 `local map = vim.keymap.set` 的写法。
    customMaps = {
      ["map"] = {
        method = "function_call",
        modeIndex = 1,
        lhsIndex = 2,
        rhsIndex = 3,
        optsIndex = 4,
      },
      ["lazy"] = {
        method = "lazy",
      },
    },
  },
  config = function(_, opts)
    require("hawtkeys").setup(opts)
  end,
}
