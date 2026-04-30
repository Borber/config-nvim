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
