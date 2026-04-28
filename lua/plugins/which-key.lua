local icons = {
  buffer = { icon = "󰈔", color = "cyan" },
  code = { icon = "", color = "orange" },
  explorer = { icon = "󰙅", color = "cyan" },
  find = { icon = "", color = "green" },
  git = { icon = "", color = "orange" },
  hunk = { icon = "", color = "yellow" },
  keys = { icon = "", color = "purple" },
  markdown = { icon = "", color = "blue" },
  quit = { icon = "󰈆", color = "red" },
  session = { icon = "", color = "azure" },
  terminal = { icon = "", color = "red" },
}

return {
  "folke/which-key.nvim",
  -- 调整为 VimEnter 事件，确保在 Vim 启动完成后加载 which-key 插件
  -- 保证第一次打开 which-key 的速度
  event = "VimEnter",
  opts = {
    preset = "helix",
    delay = 0,
    spec = {
      { "<leader>e", icon = icons.explorer, desc = "Explorer" },
      { "<leader>f", icon = icons.find, group = "find" },
      { "<leader>g", icon = icons.git, group = "git" },
      { "<leader>h", icon = icons.hunk, group = "hunk" },
      { "<leader>k", icon = icons.keys, group = "keys" },
      { "<leader>b", icon = icons.buffer, group = "buffer" },
      { "<leader>c", icon = icons.code, group = "code" },
      { "<leader>q", icon = icons.quit, group = "quit" },
      { "<leader>s", icon = icons.session, group = "session" },
      { "<leader>t", icon = icons.terminal, group = "terminal" },
      { "<leader>?", icon = icons.buffer, desc = "Buffer keymaps" },
      { "<localleader>m", icon = icons.markdown, group = "markdown" },
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
