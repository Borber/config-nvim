local M = {}

-- WakaTime CLI 查询有外部进程开销；状态栏只缓存今日总时长，按事件节流刷新。
local today = {
  text = "",
  checked_at = 0,
  pending = false,
  available = nil,
}

local refresh_interval = 5 * 60 * 1000

local function refresh_statusline(force)
  local ok, lualine = pcall(require, "lualine")
  if not ok then
    return
  end

  lualine.refresh({
    scope = "tabpage",
    place = { "statusline" },
    trigger = "autocmd",
    force = force == true,
  })
end

local function total_minutes(output)
  local text = vim.trim(tostring(output or ""))
  local hours = tonumber(text:match("(%d+)%s+hrs?")) or 0
  local minutes = tonumber(text:match("(%d+)%s+mins?")) or 0

  return hours * 60 + minutes
end

local function format_today(output)
  -- 官方摘要是英文时长文本；状态栏只保留总分钟数，减少左侧占宽。
  local minutes = total_minutes(output)
  if minutes == 0 then
    return ""
  end

  return tostring(minutes) .. "′"
end

local function request_today(force)
  local ok, wakatime = pcall(require, "wakatime")
  if not ok or type(wakatime.get_today_summary) ~= "function" then
    today.available = false
    return
  end
  today.available = true

  local now = vim.uv.now()
  if today.pending or (not force and now - today.checked_at < refresh_interval) then
    return
  end

  today.pending = true
  today.checked_at = now

  wakatime.get_today_summary(function(output)
    vim.schedule(function()
      today.pending = false
      today.text = format_today(output)
      refresh_statusline()
    end)
  end)
end

function M.component()
  return today.text
end

function M.has_today()
  if today.available == false then
    return false
  end

  request_today()

  -- 窄窗口优先让出空间给 mode/branch/diagnostics。
  return vim.o.columns > 100 and today.text ~= ""
end

function M.setup_refresh()
  if today.available == false then
    return
  end

  local group = vim.api.nvim_create_augroup("ConfigLualineWakaTime", { clear = true })

  vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained", "BufWritePost" }, {
    group = group,
    callback = function()
      request_today(true)
    end,
    desc = "Refresh lualine WakaTime today total",
  })

  vim.defer_fn(function()
    request_today(true)
  end, 1000)
end

return M
