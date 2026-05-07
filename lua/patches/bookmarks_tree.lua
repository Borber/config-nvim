-- ============================================
-- bookmarks tree patch
-- ============================================
local M = {}

local function icons()
  return require("libs.icons")
end

local function tree_context()
  return vim.g.bookmark_tree_view_ctx
end

local function compact_tree_gutter(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].statuscolumn = ""
end

function M.apply_tree_icons(buf)
  -- 上游 tree 渲染会直接写入 buffer；这里在渲染完成后做一次轻量文本替换。
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end

  local ic = icons()
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

function M.refresh_tree()
  require("bookmarks.sign").safe_refresh_signs()

  local ctx = tree_context()
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

function M.keep_width()
  -- tree 窗口可能被 split/resize 影响；下一轮事件循环再校正，确保 ctx 已更新。
  vim.schedule(function()
    local ctx = tree_context()
    if not (ctx and ctx.win and vim.api.nvim_win_is_valid(ctx.win)) then
      return
    end

    if ctx.buf and vim.api.nvim_buf_is_valid(ctx.buf) and vim.api.nvim_win_get_buf(ctx.win) ~= ctx.buf then
      return
    end

    compact_tree_gutter(ctx.win)
    M.apply_tree_icons(ctx.buf)
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

function M.apply_render_patch()
  -- render.refresh 是内部入口，必须幂等 patch，避免配置热重载后多层包裹。
  local render = require("bookmarks.tree.render")
  if render._config_icon_patch then
    return
  end

  local refresh = render.refresh
  render.refresh = function(...)
    local result = refresh(...)
    local ctx = tree_context()

    if ctx then
      M.apply_tree_icons(ctx.buf)
    end

    return result
  end
  render._config_icon_patch = true
end

return M
