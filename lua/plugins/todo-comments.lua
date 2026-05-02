return {
  "folke/todo-comments.nvim",
  -- TODO 扫描不阻塞首屏；文件可见后再补上跳转和列表能力。
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
