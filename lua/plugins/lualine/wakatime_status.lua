local M = {}

-- WakaTime CLI 查询有外部进程开销；状态栏只缓存今日总时长，按事件节流刷新。
local today = {
  text = "",
  checked_at = nil,
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

local function append_output(lines, data)
  if type(data) ~= "table" then
    return
  end

  for _, line in ipairs(data) do
    if line ~= "" then
      table.insert(lines, line)
    end
  end
end

local function decode_total_seconds(output)
  local decoded = vim.json.decode(table.concat(output, "\n"))
  return decoded.data.grand_total.total_seconds
end

local function format_today(output)
  -- 直接读取 CLI JSON 里的秒数，避免从英文摘要文本反推时间。
  -- 即使今天还没累计时长，也保留 `0′`，让状态段保持可见。
  local minutes = math.floor(decode_total_seconds(output) / 60)

  local icons = require("libs.icons")

  return icons.ui.time .. " " .. tostring(minutes) .. "′"
end

local function wakatime_cli()
  local cli = vim.fn.exepath("wakatime-cli")
  if cli ~= "" then
    return cli
  end

  return vim.fn.exepath("wakatime")
end

local function request_today()
  local cli = wakatime_cli()
  if cli == "" then
    today.available = false
    return
  end
  today.available = true

  local now = vim.uv.now()
  if today.pending or (today.checked_at ~= nil and now - today.checked_at < refresh_interval) then
    return
  end

  today.pending = true
  today.checked_at = now

  local output = {}
  local job = vim.fn.jobstart({ cli, "--today", "--output", "raw-json" }, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      append_output(output, data)
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        today.pending = false
        today.text = exit_code == 0 and format_today(output) or ""
        refresh_statusline()
      end)
    end,
  })

  if not job or job <= 0 then
    today.pending = false
    today.text = ""
    vim.schedule(function()
      refresh_statusline()
    end)
  end
end

function M.component()
  return today.text
end

function M.has_today()
  if today.available == false then
    return false
  end

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
      request_today()
    end,
    desc = "Refresh lualine WakaTime today total",
  })

  vim.defer_fn(function()
    request_today()
  end, 1000)
end

return M
