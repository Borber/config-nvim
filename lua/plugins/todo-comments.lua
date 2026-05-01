return {
  "folke/todo-comments.nvim",
  -- TODO 扫描只对真实文件有意义，和 gitsigns 一起挂到 ConfigFilePost。
  event = "User ConfigFilePost",
  cmd = { "TodoTrouble", "TodoTelescope" },
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {},
  keys = {
    {
      "]t",
      function()
        require("todo-comments").jump_next()
      end,
      desc = "Next todo",
    },
    {
      "[t",
      function()
        require("todo-comments").jump_prev()
      end,
      desc = "Prev todo",
    },
    { "<leader>ft", "<Cmd>TodoTelescope<CR>", desc = "Todo" },
  },
}
