local ic = require("libs.icons")

local function project_name()
  local name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  return name ~= "" and name or nil
end

local function configure_sqlite_clib()
  -- Windows 上 sqlite.lua 需要显式找到 dll；Scoop 路径只在未配置时作为本机默认值。
  if vim.g.sqlite_clib_path ~= nil or vim.fn.has("win32") == 0 then
    return
  end

  vim.g.sqlite_clib_path = vim.fn.expand("~/scoop/apps/sqlite-dll/current/sqlite3.dll")
end

local function refresh_bookmarks()
  -- 切换项目列表后总是刷新 sign；tree 只有窗口真实存在时才刷新。
  require("bookmarks.sign").safe_refresh_signs()

  local ctx = vim.g.bookmark_tree_view_ctx
  if ctx == nil then
    return
  end

  if not (ctx.win and vim.api.nvim_win_is_valid(ctx.win) and ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf)) then
    vim.g.bookmark_tree_view_ctx = nil
    vim.notify("Bookmarks tree context is stale; skipped tree refresh", vim.log.levels.WARN)
    return
  end

  if not (ctx.lines_ctx and ctx.lines_ctx.root_id) then
    vim.notify("Bookmarks tree context is not ready; skipped tree refresh", vim.log.levels.WARN)
    return
  end

  require("bookmarks.tree.operate").refresh()
end

local function compact_tree_gutter(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].statuscolumn = ""
end

local function apply_tree_icons(buf)
  -- 上游 tree 渲染会直接写入 buffer；这里在渲染完成后做一次轻量文本替换。
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local changed = false

  for index, line in ipairs(lines) do
    local updated = line:gsub("^(%s*)▾", "%1" .. ic.tree.expanded, 1)
    updated = updated:gsub("^(%s*)▸", "%1" .. ic.tree.collapsed, 1)

    if updated ~= line then
      lines[index] = updated
      changed = true
    end
  end

  if changed then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
end

local function patch_tree_icons()
  -- render.refresh 是内部入口，必须幂等 patch，避免配置重载后多层包裹。
  local render = require("bookmarks.tree.render")
  if render._config_icon_patch then
    return
  end

  local refresh = render.refresh
  render.refresh = function(...)
    local result = refresh(...)
    local ctx = vim.g.bookmark_tree_view_ctx

    if ctx then
      apply_tree_icons(ctx.buf)
    end

    return result
  end
  render._config_icon_patch = true
end

local function keep_tree_width()
  -- tree 窗口可能被 split/resize 影响；下一轮事件循环再校正，确保 ctx 已更新。
  vim.schedule(function()
    local ctx = vim.g.bookmark_tree_view_ctx
    if not (ctx and ctx.win and vim.api.nvim_win_is_valid(ctx.win)) then
      return
    end

    if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) and vim.api.nvim_win_get_buf(ctx.win) ~= ctx.buf then
      return
    end

    compact_tree_gutter(ctx.win)
    apply_tree_icons(ctx.buf)
    vim.wo[ctx.win].winfixwidth = true

    local width = ((vim.g.bookmarks_config or {}).treeview or {}).window_split_dimension or 50
    if vim.api.nvim_win_get_width(ctx.win) ~= width then
      local ok, err = pcall(vim.api.nvim_win_set_width, ctx.win, width)
      if not ok then
        vim.notify("Failed to resize bookmarks tree: " .. tostring(err), vim.log.levels.ERROR)
      end
    end
  end)
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

  return ic.tree.bookmark .. " " .. name
end

local function create_project_commands()
  vim.api.nvim_create_user_command("BookmarksProjectActivate", function()
    activate_project_list({ create = true, notify = true })
  end, { desc = "Use current cwd as the active bookmark list" })

  vim.api.nvim_create_user_command("BookmarksProjectTree", function()
    activate_project_list({ create = true })
    vim.cmd("BookmarksTree")
    keep_tree_width()
  end, { desc = "Open bookmarks tree for current cwd" })
end

local function setup_project_autocmds()
  local group = vim.api.nvim_create_augroup("config_bookmarks_project", { clear = true })

  -- VeryLazy 后插件才可用，延后一拍再尝试同步当前 cwd 的列表。
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
  init = configure_sqlite_clib,
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
        activate_project_list({ create = true })
        vim.cmd("BookmarksTree")
        keep_tree_width()
      end,
    },
  },
  config = function(_, opts)
    require("bookmarks").setup(opts)
    patch_tree_icons()
    create_project_commands()
    setup_project_autocmds()
  end,
}
