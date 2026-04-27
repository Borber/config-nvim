return {
  "folke/which-key.nvim",
  event = "VeryLazy",
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
