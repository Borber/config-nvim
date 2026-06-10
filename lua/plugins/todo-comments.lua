local lifecycle = require("config.lifecycle")

return {
  "folke/todo-comments.nvim",
  -- TODO 扫描不阻塞首屏；文件可见后再补上跳转和列表能力。
  event = lifecycle.lazy_events.file_post,
  cmd = { "TodoTrouble", "TodoFzfLua" },
  dependencies = { "nvim-lua/plenary.nvim", "ibhagwan/fzf-lua" },
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
    { "<leader>ft", "<Cmd>TodoFzfLua<CR>", desc = "Todo" },
  },
}
