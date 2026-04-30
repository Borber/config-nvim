local group = vim.api.nvim_create_augroup("config_bookmarks_project", { clear = true })
local function project_name()
  local cwd = vim.fn.getcwd()
  local name = vim.fn.fnamemodify(cwd, ":t")

  if name ~= "" then
    return name
  end

  return cwd ~= "" and cwd or nil
end

local function refresh_bookmarks()
  pcall(function()
    require("bookmarks.sign").safe_refresh_signs()
  end)
  pcall(function()
    require("bookmarks.tree.operate").refresh()
  end)
end

local function configured_tree_width()
  local config = vim.g.bookmarks_config or {}
  local treeview = config.treeview or {}

  return treeview.window_split_dimension or 50
end

local function keep_tree_width()
  vim.schedule(function()
    local ctx = vim.g.bookmark_tree_view_ctx
    if not (ctx and ctx.win and vim.api.nvim_win_is_valid(ctx.win)) then
      return
    end

    if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) and vim.api.nvim_win_get_buf(ctx.win) ~= ctx.buf then
      return
    end

    vim.wo[ctx.win].winfixwidth = true

    local width = configured_tree_width()
    if vim.api.nvim_win_get_width(ctx.win) ~= width then
      pcall(vim.api.nvim_win_set_width, ctx.win, width)
    end
  end)
end

local function activate_project_list(opts)
  opts = opts or {}

  local name = project_name()
  if name == nil then
    return nil
  end

  local repo = require("bookmarks.domain.repo")
  local service = require("bookmarks.domain.service")

  for _, list in ipairs(repo.find_lists()) do
    if list.name == name then
      service.set_active_list(list.id)
      refresh_bookmarks()
      return list
    end
  end

  if not opts.create then
    service.set_active_list(0)
    refresh_bookmarks()
    return nil
  end

  local ok, list = pcall(service.create_list, name, 0)
  if not ok then
    vim.notify("Create bookmark list failed: " .. tostring(list), vim.log.levels.ERROR)
    return nil
  end

  if opts.notify then
    vim.notify("Bookmark project: " .. name, vim.log.levels.INFO)
  end

  refresh_bookmarks()
  return list
end

local function run_project_command(command, opts)
  return function()
    activate_project_list(opts)
    vim.cmd(command)

    if command == "BookmarksTree" then
      keep_tree_width()
    end
  end
end

local function bookmark_tree_label(bookmark)
  local name = bookmark.name
  if name == nil or name == "" then
    name = "[Untitled]"
  end

  return "○ " .. name
end

local function create_project_commands()
  vim.api.nvim_create_user_command("BookmarksProjectActivate", function()
    activate_project_list({ create = true, notify = true })
  end, { desc = "Use current cwd as the active bookmark list" })

  vim.api.nvim_create_user_command("BookmarksProjectTree", function()
    run_project_command("BookmarksTree", { create = true })()
  end, { desc = "Open bookmarks tree for current cwd" })
end

local function setup_project_autocmds()
  vim.schedule(function()
    activate_project_list({ create = false })
  end)

  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      activate_project_list({ create = false })
    end,
    desc = "Switch bookmarks list when cwd changes",
  })

  vim.api.nvim_create_autocmd({ "WinNew", "WinResized", "VimResized" }, {
    group = group,
    callback = keep_tree_width,
    desc = "Keep bookmarks tree at its configured width",
  })
end

return {
  "LintaoAmons/bookmarks.nvim",
  event = "VeryLazy",
  cmd = {
    "BookmarkRebindOrphanNode",
    "BookmarksCommands",
    "BookmarksDesc",
    "BookmarksGoto",
    "BookmarksGotoNext",
    "BookmarksGotoNextInList",
    "BookmarksGotoPrev",
    "BookmarksGotoPrevInList",
    "BookmarksGrep",
    "BookmarksInfo",
    "BookmarksInfoCurrentBookmark",
    "BookmarksLists",
    "BookmarksMark",
    "BookmarksNewList",
    "BookmarksProjectActivate",
    "BookmarksProjectTree",
    "BookmarksQuery",
    "BookmarksTree",
  },
  keys = {
    { "<leader>mm", run_project_command("BookmarksMark", { create = true }), desc = "Bookmark line" },
    { "<leader>mo", run_project_command("BookmarksGoto", { create = true }), desc = "Project bookmarks" },
    { "<leader>mt", run_project_command("BookmarksTree", { create = true }), desc = "Project bookmark tree" },
    { "<leader>ma", run_project_command("BookmarksCommands", { create = true }), desc = "Bookmark actions" },
  },
  dependencies = {
    "kkharji/sqlite.lua",
    "nvim-telescope/telescope.nvim",
  },
  opts = {
    calibrate = {
      show_calibrate_logs = false,
    },
    signs = {
      mark = {
        icon = "",
        color = "#e0af68",
        line_bg = "NONE",
      },
      desc_format = function()
        return ""
      end,
    },
    treeview = {
      render_bookmark = bookmark_tree_label,
      window_split_dimension = 50,
    },
    commands = {
      use_current_cwd = function()
        activate_project_list({ create = true, notify = true })
      end,
      open_project_tree = function()
        run_project_command("BookmarksTree", { create = true })()
      end,
    },
  },
  config = function(_, opts)
    require("bookmarks").setup(opts)
    create_project_commands()
    setup_project_autocmds()
  end,
}
