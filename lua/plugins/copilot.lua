return {
  -- 关闭 Copilot 自带面板和内联建议，统一走 blink 的候选菜单。
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  opts = {
    panel = {
      enabled = false,
    },
    suggestion = {
      enabled = false,
    },
    filetypes = {
      markdown = true,
    },
    server_opts_overrides = {
      settings = {
        advanced = {
          inlineSuggestCount = 5,
        },
      },
    },
  },
}
