return {
  "NeogitOrg/neogit",
  cmd = "Neogit",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "sindrets/diffview.nvim",
    -- 让 Neogit 的 commit popup 能调用 AI commit action。
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
    builders = {
      NeogitCommitPopup = function(builder)
        -- 把 AI commit 放进 `c` commit popup 内部，而不是 Neogit status 的独立快捷键。
        -- `-C` 仍然是 Git 原生 reuse-message 参数；这里的 `C` 是 popup action。
        builder:new_action_group("AI"):action("C", "AI Commit", function()
          require("aicommits").commit()
        end)
      end,
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
