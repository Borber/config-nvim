local M = {}
local enabled = false

-- 这个模块只保存 Starter Open 的一次性模式开关。
-- 它不代表普通 mini.files 状态，只决定是否给当前 buffer 安装 <S-CR>。
local function current_entry()
  local minifiles = package.loaded["mini.files"]
  if minifiles == nil or type(minifiles.get_fs_entry) ~= "function" then
    return
  end

  local entry = minifiles.get_fs_entry()
  if entry == nil then
    return
  end

  return minifiles, entry
end

local function open_path(path)
  require("mini.files").close()
  require("plugins.mini.visits").open_path(path)
end

function M.enable()
  enabled = true
end

function M.disable()
  enabled = false
end

function M.attach_buffer(buf_id)
  if not enabled then
    return
  end

  -- 只有 Starter 打开的这次文件树才允许 <S-CR> 作为“最终确认”入口。
  vim.keymap.set("n", "<S-CR>", M.confirm_selected_entry, {
    buffer = buf_id,
    desc = "Open selected path",
    silent = true,
  })
end

function M.confirm_selected_entry()
  local _, entry = current_entry()
  if entry == nil then
    return
  end

  -- 最终确认的路径统一交给 visits.open_path，确保 recent / cwd / session 流程一致。
  open_path(entry.path)
end

return M
