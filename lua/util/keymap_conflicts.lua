local M = {}

local STATE_KEY = "_keymap_conflicts_state"
local list_unpack = table.unpack or unpack
local IGNORE_FRAGMENTS = {
  "lazy/core/",
}
local IGNORE_SUFFIXES = {
  "lua/util/keymap_conflicts.lua",
  "vim/keymap.lua",
}

local function has_suffix(text, suffix)
  return suffix == "" or text:sub(-#suffix) == suffix
end

local function ignored_source(path)
  -- lazy.nvim 和本工具自身会间接调用 keymap.set，这些来源不算真实用户配置冲突。
  for _, fragment in ipairs(IGNORE_FRAGMENTS) do
    if path:find(fragment, 1, true) then
      return true
    end
  end

  for _, suffix in ipairs(IGNORE_SUFFIXES) do
    if has_suffix(path, suffix) then
      return true
    end
  end

  return false
end

local function state()
  -- 把状态挂到 vim 上，确保 :R 重新加载模块后仍能沿用同一份记录和原函数。
  local current = rawget(vim, STATE_KEY)

  if current ~= nil then
    return current
  end

  current = {
    initialized = false,
    command_created = false,
    in_keymap_set = 0,
    seen = {},
    conflicts = {},
    originals = {},
  }

  rawset(vim, STATE_KEY, current)

  return current
end

local function mode_list(mode)
  if type(mode) == "table" then
    return mode
  end

  return { mode }
end

local function caller_site()
  -- 从调用栈里找到第一个“像用户配置”的位置，用它标记键位来自哪里。
  for level = 3, 12 do
    local info = debug.getinfo(level, "Sln")

    if info ~= nil then
      local source = info.source or ""

      if source == "" or source:sub(1, 1) == "=" then
        goto continue
      end

      if source:sub(1, 1) == "@" then
        source = source:sub(2)
      end

      if source ~= "" and not ignored_source(source) then
        local path = vim.fs.normalize(source)

        if not ignored_source(path) then
          return ("%s:%d"):format(path, info.currentline or 0)
        end
      end
    end

    ::continue::
  end

  return nil
end

local function add_conflict(current, mode, lhs, previous, latest)
  current.conflicts[#current.conflicts + 1] = {
    mode = mode,
    lhs = lhs,
    previous = previous,
    latest = latest,
  }

  -- 记录时用 schedule 通知，避免在 keymap.set 的调用链里直接打断插件初始化。
  vim.schedule(function()
    vim.notify(
      ("Global keymap conflict [%s] %s\nold: %s\nnew: %s"):format(mode, lhs, previous, latest),
      vim.log.levels.WARN
    )
  end)
end

local function record(mode, lhs)
  local current = state()
  local current_mode = tostring(mode)
  local current_lhs = tostring(lhs)
  local key = table.concat({ current_mode, current_lhs }, "\31")
  local latest = caller_site()

  if latest == nil then
    return
  end

  local previous = current.seen[key]

  if previous ~= nil and previous ~= latest then
    add_conflict(current, current_mode, current_lhs, previous, latest)
  end

  current.seen[key] = latest
end

local function open_report()
  local current = state()

  if #current.conflicts == 0 then
    vim.notify("No global keymap conflicts recorded", vim.log.levels.INFO)
    return
  end

  local lines = {
    "Global keymap conflicts",
    "",
  }

  for index, item in ipairs(current.conflicts) do
    lines[#lines + 1] = ("%d. [%s] %s"):format(index, item.mode, item.lhs)
    lines[#lines + 1] = ("   old: %s"):format(item.previous)
    lines[#lines + 1] = ("   new: %s"):format(item.latest)
    lines[#lines + 1] = ""
  end

  vim.cmd("botright new")

  local buf = vim.api.nvim_get_current_buf()

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.bo[buf].filetype = "text"

  vim.api.nvim_buf_set_name(buf, "keymap-conflicts")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.bo[buf].modifiable = false
end

function M.setup()
  local current = state()

  if current.initialized then
    return
  end

  current.initialized = true
  current.originals.keymap_set = vim.keymap.set
  current.originals.nvim_set_keymap = vim.api.nvim_set_keymap

  -- 包裹 vim.keymap.set：只跟踪全局键位，buffer-local 键位通常由 LSP/插件按 buffer 创建。
  vim.keymap.set = function(mode, lhs, rhs, opts)
    opts = opts or {}

    if opts.buffer == nil or opts.buffer == false then
      for _, item_mode in ipairs(mode_list(mode)) do
        record(item_mode, lhs)
      end
    end

    current.in_keymap_set = current.in_keymap_set + 1

    local results = { pcall(current.originals.keymap_set, mode, lhs, rhs, opts) }

    current.in_keymap_set = current.in_keymap_set - 1

    if not results[1] then
      error(results[2])
    end

    return list_unpack(results, 2)
  end

  -- 兼容仍然使用旧 API 的插件或配置；in_keymap_set 用来避免重复记录同一次调用。
  vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
    if current.in_keymap_set == 0 then
      record(mode, lhs)
    end

    return current.originals.nvim_set_keymap(mode, lhs, rhs, opts)
  end

  if not current.command_created then
    current.command_created = true
    vim.api.nvim_create_user_command("CheckKeymapConflicts", open_report, {
      desc = "Show recorded global keymap conflicts",
    })
  end
end

return M
