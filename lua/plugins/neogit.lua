return {
  "NeogitOrg/neogit",
  cmd = "Neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "sindrets/diffview.nvim",
    -- 让 Neogit 打开时同时加载 AI commit 集成；status buffer 里可按 C 生成提交。
    "404pilo/aicommits.nvim",
  },
  keys = {
    { "<leader>hg", "<cmd>Neogit<cr>", desc = "Git status" },
    { "<leader>hc", "<cmd>Neogit commit<cr>", desc = "Git commit" },
    { "<leader>hl", "<cmd>Neogit log<cr>", desc = "Git log" },
  },
  opts = {
    kind = "auto",
    commit_editor = {
      kind = "auto",
    },
    commit_select_view = {
      kind = "auto",
    },
    log_view = {
      kind = "auto",
    },
    reflog_view = {
      kind = "auto",
    },
    refs_view = {
      kind = "auto",
    },
    stash = {
      kind = "auto",
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
