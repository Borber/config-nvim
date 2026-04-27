local function default_neogit_cwd()
  local git = require("util.git")
  local cwd = vim.fn.getcwd()
  local dir = git.dir_from_tab_file(0) or cwd

  return git.root_from(dir) or git.root_from(cwd) or dir
end

local function popup_repo_cwd(opts)
  if not opts.cwd then
    return nil
  end

  if opts.no_expand then
    return opts.cwd
  end

  return vim.fn.expand(opts.cwd)
end

local function open_neogit(args)
  return function()
    local opts = require("neogit.lib.util").parse_command_args(args or {})

    if not opts.cwd then
      opts.cwd = default_neogit_cwd()
      opts.no_expand = true
    end

    -- Direct popups use Neogit's current repo instance; seed it with our cwd.
    local repo_cwd = popup_repo_cwd(opts)
    if opts[1] and repo_cwd then
      require("neogit.lib.git.repository").instance(repo_cwd)
    end

    require("neogit").open(opts)
    require("util.neogit_loading").start(opts)
  end
end

local function create_neogit_command()
  vim.api.nvim_create_user_command("Neogit", function(command)
    open_neogit(command.fargs)()
  end, {
    nargs = "*",
    desc = "Open Neogit",
    complete = function(arglead)
      return require("neogit").complete(arglead)
    end,
    force = true,
  })
end

return {
  "NeogitOrg/neogit",
  init = create_neogit_command,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
    "sindrets/diffview.nvim",
    -- 让 Neogit 的 commit popup 能调用 AI commit action。
    "404pilo/aicommits.nvim",
  },
  keys = {
    { "<leader>hg", open_neogit(), desc = "Git status" },
    { "<leader>hc", open_neogit({ "commit" }), desc = "Git commit" },
    { "<leader>hl", open_neogit({ "log" }), desc = "Git log" },
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
  config = function(_, opts)
    require("neogit").setup(opts)
    create_neogit_command()
  end,
}
