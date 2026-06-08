return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
  },
  init = function()
    vim.g.tmux_navigator_no_mappings = 1
  end,
  keys = {
    { "<C-h>", "<Cmd>TmuxNavigateLeft<CR>", mode = "n", desc = "Navigate left" },
    { "<C-j>", "<Cmd>TmuxNavigateDown<CR>", mode = "n", desc = "Navigate down" },
    { "<C-k>", "<Cmd>TmuxNavigateUp<CR>", mode = "n", desc = "Navigate up" },
    { "<C-l>", "<Cmd>TmuxNavigateRight<CR>", mode = "n", desc = "Navigate right" },
    { "<C-h>", [[<C-\><C-n><Cmd>TmuxNavigateLeft<CR>]], mode = "t", desc = "Navigate left" },
    { "<C-j>", [[<C-\><C-n><Cmd>TmuxNavigateDown<CR>]], mode = "t", desc = "Navigate down" },
    { "<C-k>", [[<C-\><C-n><Cmd>TmuxNavigateUp<CR>]], mode = "t", desc = "Navigate up" },
    { "<C-l>", [[<C-\><C-n><Cmd>TmuxNavigateRight<CR>]], mode = "t", desc = "Navigate right" },
  },
}
