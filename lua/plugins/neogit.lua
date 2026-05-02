local function default_neogit_cwd()
  local git = require("libs.git")
  local cwd = vim.fn.getcwd()
  -- 调用时如果在真实文件 buffer，就用文件位置推导仓库；特殊 buffer 直接回退 cwd。
  local dir = git.dir_from_buffer(0) or cwd

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

    -- 直接打开 commit/log 等 popup 时，先用我们的 cwd 初始化 Neogit 仓库实例。
    local repo_cwd = popup_repo_cwd(opts)
    if opts[1] and repo_cwd then
      require("neogit.lib.git.repository").instance(repo_cwd)
    end

    require("neogit").open(opts)
    require("custom.neogit_loading").start(opts)
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

local fold_signs = {
  closed = vim.fn.nr2char(0xf460),
  open = vim.fn.nr2char(0xf47c),
}

local function current_status_buffer()
  local status = require("neogit.buffers.status")
  local instance = status.instance(vim.fn.getcwd(0))
  if instance == nil or instance.buffer == nil then
    return
  end

  if instance.buffer.handle ~= vim.api.nvim_get_current_buf() then
    return
  end

  return instance
end

local stageable_sections = {
  unstaged = true,
  untracked = true,
}

-- 用 Neogit 的 UI 元数据判断当前位置，避免靠显示文本猜 section。
local function on_stageable_file(status)
  local selection = status.buffer.ui:get_selection()
  local section = selection.section
  local cursor = status.buffer.ui:get_cursor_location()

  return selection.item ~= nil and section ~= nil and stageable_sections[section.name] and cursor ~= nil and cursor.file ~= nil and cursor.hunk == nil
end

local function stage_file_or_hop()
  local status = current_status_buffer()
  if status ~= nil and on_stageable_file(status) then
    -- 只在可 stage 的文件行复用 Neogit 原生 stage；hunk/标题/其它区域交回 Hop。
    status:_action("n_stage")()
    return
  end

  require("plugins.hop").hint_by_context()
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
    { "<leader>gg", open_neogit(), desc = "Git status" },
    { "<leader>gc", open_neogit({ "commit" }), desc = "Git commit" },
    { "<leader>gl", open_neogit({ "log" }), desc = "Git log" },
  },
  opts = function()
    local float = require("util.float")

    return {
      kind = "auto",
      floating = {
        border = float.border,
      },
      graph_style = "unicode",
      signs = {
        hunk = { "", "" },
        item = { fold_signs.closed, fold_signs.open },
        section = { fold_signs.closed, fold_signs.open },
      },
      status = {
        HEAD_padding = 8,
        mode_padding = 2,
        mode_text = {
          M = "● modified",
          N = "+ new file",
          A = "+ added",
          D = "- deleted",
          C = "· copied",
          U = "! updated",
          R = "→ renamed",
          T = "● changed",
          DD = "! unmerged",
          AU = "! unmerged",
          UD = "! unmerged",
          UA = "! unmerged",
          DU = "! unmerged",
          AA = "! unmerged",
          UU = "! unmerged",
          ["?"] = "",
        },
      },
      mappings = {
        status = {
          s = stage_file_or_hop,
        },
      },
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
    }
  end,
  config = function(_, opts)
    require("neogit").setup(opts)
    require("plugins.neogit.highlights").apply()
  end,
}
