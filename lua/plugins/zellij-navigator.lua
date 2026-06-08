return {
  "swaits/zellij-nav.nvim",
  cmd = {
    "ZellijNavigateLeft",
    "ZellijNavigateDown",
    "ZellijNavigateUp",
    "ZellijNavigateRight",
    "ZellijNavigateLeftTab",
    "ZellijNavigateRightTab",
  },
  keys = {
    { "<M-h>", "<Cmd>ZellijNavigateLeftTab<CR>", mode = "n", desc = "Navigate left or tab", silent = true },
    { "<M-j>", "<Cmd>ZellijNavigateDown<CR>", mode = "n", desc = "Navigate down", silent = true },
    { "<M-k>", "<Cmd>ZellijNavigateUp<CR>", mode = "n", desc = "Navigate up", silent = true },
    { "<M-l>", "<Cmd>ZellijNavigateRightTab<CR>", mode = "n", desc = "Navigate right or tab", silent = true },
    { "<M-h>", [[<C-\><C-n><Cmd>ZellijNavigateLeftTab<CR>]], mode = "t", desc = "Navigate left or tab", silent = true },
    { "<M-j>", [[<C-\><C-n><Cmd>ZellijNavigateDown<CR>]], mode = "t", desc = "Navigate down", silent = true },
    { "<M-k>", [[<C-\><C-n><Cmd>ZellijNavigateUp<CR>]], mode = "t", desc = "Navigate up", silent = true },
    { "<M-l>", [[<C-\><C-n><Cmd>ZellijNavigateRightTab<CR>]], mode = "t", desc = "Navigate right or tab", silent = true },
  },
  opts = {},
}
