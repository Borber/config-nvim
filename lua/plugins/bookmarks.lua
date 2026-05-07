local function icons()
  return require("libs.icons")
end

local tree_patch = require("patches.bookmarks_tree")

local function project_name()
  local name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  return name ~= "" and name or nil
end

local function refresh_bookmarks()
  -- 切换项目列表后总是刷新 sign；tree 只有窗口真实存在时才刷新。
  tree_patch.refresh_tree()
end

local function activate_project_list(opts)
  opts = opts or {}

  -- 每个 cwd 对应一个同名书签列表；不存在时按调用场景决定是否创建。
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
    -- 所有书签命令先切到当前项目列表，避免手动命令误操作到别的项目。
    local list = activate_project_list(opts)
    if opts and opts.create and list == nil then
      return
    end

    vim.cmd(command)

    if command == "BookmarksTree" then
      tree_patch.keep_width()
    end
  end
end

local function bookmark_tree_label(bookmark)
  local name = bookmark.name
  if name == nil or name == "" then
    name = "[Untitled]"
  end

  local ic = icons()
  return ic.tree.bookmark .. " " .. name
end

local function create_project_commands()
  vim.api.nvim_create_user_command("BookmarksProjectActivate", function()
    activate_project_list({ create = true, notify = true })
  end, { desc = "Use current cwd as the active bookmark list" })

  vim.api.nvim_create_user_command("BookmarksProjectTree", function()
    activate_project_list({ create = true })
    vim.cmd("BookmarksTree")
    tree_patch.keep_width()
  end, { desc = "Open bookmarks tree for current cwd" })
end

local function setup_project_autocmds()
  local group = vim.api.nvim_create_augroup("config_bookmarks_project", { clear = true })

  -- 插件加载后延后一拍再尝试同步当前 cwd 的列表，避免抢在项目上下文稳定前刷新。
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
    callback = tree_patch.keep_width,
    desc = "Keep bookmarks tree at its configured width",
  })
end

return {
  "LintaoAmons/bookmarks.nvim",
  init = function()
    require("util.sqlite").configure_clib()
  end,
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
  opts = function()
    local ic = icons()

    return {
      calibrate = {
        show_calibrate_logs = false,
      },
      signs = {
        mark = {
          icon = ic.ui.bookmark,
          color = "#e0af68",
          line_bg = "NONE",
        },
        desc_format = function()
          return ""
        end,
      },
      treeview = {
        active_list_icon = ic.tree.active .. " ",
        render_bookmark = bookmark_tree_label,
        window_split_dimension = 50,
      },
      commands = {
        use_current_cwd = function()
          activate_project_list({ create = true, notify = true })
        end,
        open_project_tree = function()
          if activate_project_list({ create = true }) == nil then
            return
          end

          vim.cmd("BookmarksTree")
          tree_patch.keep_width()
        end,
      },
    }
  end,
  config = function(_, opts)
    require("bookmarks").setup(opts)
    tree_patch.apply_render_patch()
    create_project_commands()
    setup_project_autocmds()
  end,
}
