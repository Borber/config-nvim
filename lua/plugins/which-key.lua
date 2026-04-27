return {
  "folke/which-key.nvim",
  -- 调整为 VimEnter 事件，确保在 Vim 启动完成后加载 which-key 插件
  -- 保证第一次打开 which-key 的速度
  event = "VimEnter",
  opts = {
    preset = "helix",
    delay = 0,
    spec = {
      { "<leader>e", group = "file" },
      { "<leader>f", group = "find" },
      { "<leader>h", group = "git" },
      { "<leader>c", group = "code" },
      { "<leader>r", group = "code" },
      { "<leader>q", group = "quit" },
      { "<leader>t", group = "tab" },
      { "<localleader>t", group = "terminal" },
      { "<localleader>m", group = "markdown" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer keymaps",
    },
  },
}
