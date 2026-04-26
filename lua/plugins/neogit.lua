return {
  "NeogitOrg/neogit",
  cmd = "Neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "sindrets/diffview.nvim",
  },
  keys = {
    { "<leader>hg", "<cmd>Neogit<cr>", desc = "Git status" },
    { "<leader>hc", "<cmd>Neogit commit<cr>", desc = "Git commit" },
    { "<leader>hl", "<cmd>Neogit log<cr>", desc = "Git log" },
  },
  opts = {
    kind = "floating",
    floating = {
      width = 0.8,
      height = 0.7,
      border = "rounded",
    },
    commit_editor = {
      kind = "floating",
    },
    commit_select_view = {
      kind = "floating",
    },
    log_view = {
      kind = "floating",
    },
    reflog_view = {
      kind = "floating",
    },
    refs_view = {
      kind = "floating",
    },
    stash = {
      kind = "floating",
    },
    integrations = {
      telescope = true,
      diffview = true,
      fzf_lua = false,
      mini_pick = false,
      snacks = false,
    },
  },
}
