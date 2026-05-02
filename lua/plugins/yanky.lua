return {
  "gbprod/yanky.nvim",
  event = "User ConfigUiReady",
  init = function()
    require("util.sqlite").configure_clib()
  end,
  keys = {
    {
      "<leader>p",
      function()
        require("telescope").extensions.yank_history.yank_history()
      end,
      desc = "Yank history",
    },
  },
  dependencies = {
    "kkharji/sqlite.lua",
  },
  opts = {
    ring = {
      history_length = 10000,
      storage = "sqlite",
      storage_path = vim.fn.stdpath("data") .. "/databases/yanky.db",
    },
    highlight = {
      on_put = true,
      on_yank = true,
      timer = 200,
    },
  },
  config = function(_, opts)
    require("yanky").setup(opts)

    vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)", { silent = true })
    vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)", { silent = true })
    vim.keymap.set("n", "<C-p>", "<Plug>(YankyPreviousEntry)", { silent = true })
    vim.keymap.set("n", "<C-n>", "<Plug>(YankyNextEntry)", { silent = true })
  end,
}
