local M = {}

local frames = { "⣾", "⣷", "⣯", "⣟", "⡿", "⢿", "⣻", "⣽" }
local active

local function repo_name(opts)
  local cwd = opts.cwd
  if cwd and not opts.no_expand then
    cwd = vim.fn.expand(cwd)
  end

  local name = cwd and vim.fn.fnamemodify(cwd, ":t") or "repository"
  return name ~= "" and name or cwd or "repository"
end

local function message(opts)
  if opts[1] then
    return ("Opening Neogit %s in %s"):format(opts[1], repo_name(opts))
  end

  return ("Loading Neogit status in %s"):format(repo_name(opts))
end

local function stop_active()
  -- 同一时间只允许一个 loading 占位；停止时恢复窗口选项、timer 和临时 autocmd。
  if not active then
    return
  end

  local current = active
  active = nil

  if vim.api.nvim_win_is_valid(current.win) then
    vim.api.nvim_set_option_value("signcolumn", current.signcolumn, { win = current.win })
  end

  current.timer:stop()
  if not current.timer:is_closing() then
    current.timer:close()
  end

  pcall(vim.api.nvim_del_augroup_by_id, current.group)
end

function M.start(opts, win)
  opts = opts or {}
  stop_active()

  local target_win = win and vim.api.nvim_win_is_valid(win) and win or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(target_win)
  -- 只接管 Neogit 自己的空白/状态 buffer，避免误把普通文件内容替换成 loading 文案。
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) or not vim.bo[buf].filetype:match("^Neogit") then
    return function() end
  end

  local signcolumn = vim.api.nvim_get_option_value("signcolumn", { win = target_win })
  local group = vim.api.nvim_create_augroup("ConfigNeogitLoading", { clear = true })
  local timer = assert(vim.uv.new_timer())
  local text = message(opts)
  local tick = 1

  active = { group = group, signcolumn = signcolumn, timer = timer, win = target_win }
  -- loading 期间隐藏 signcolumn，让居中文案不会被左侧列挤歪。
  vim.api.nvim_set_option_value("signcolumn", "no", { win = target_win })

  local function centered_lines(line)
    local height = math.max(1, vim.api.nvim_win_get_height(target_win))
    local width = math.max(1, vim.api.nvim_win_get_width(target_win))
    local row = math.max(1, math.ceil(height / 2))
    local padding = math.max(0, math.floor((width - vim.fn.strdisplaywidth(line)) / 2))
    local lines = vim.fn["repeat"]({ "" }, height)

    lines[row] = string.rep(" ", padding) .. line

    return lines
  end

  local function render()
    -- timer 回调可能晚于窗口关闭或下一次 Neogit 打开，先确认仍是当前 active 实例。
    if not active or active.timer ~= timer then
      return
    end

    if
      not vim.api.nvim_win_is_valid(target_win)
      or not vim.api.nvim_buf_is_valid(buf)
      or not vim.api.nvim_buf_is_loaded(buf)
    then
      stop_active()
      return
    end

    local line = ("%s %s"):format(frames[tick], text)
    local readonly = vim.api.nvim_get_option_value("readonly", { buf = buf })
    -- Neogit buffer 通常是不可改的；短暂打开 modifiable 只用于替换占位内容。
    vim.api.nvim_set_option_value("readonly", false, { buf = buf })
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, centered_lines(line))
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    vim.api.nvim_set_option_value("readonly", readonly, { buf = buf })
  end

  local function stop()
    if active and active.timer == timer then
      stop_active()
    end
  end

  -- status refresh 或 popup filetype 出现时说明 Neogit 已经接管渲染，可以撤掉占位。
  vim.api.nvim_create_autocmd(opts[1] and "FileType" or "User", {
    group = group,
    pattern = opts[1] and "NeogitPopup" or "NeogitStatusRefreshed",
    once = true,
    callback = stop,
  })

  vim.api.nvim_create_autocmd({ "BufHidden", "BufWipeout" }, {
    group = group,
    buffer = buf,
    once = true,
    callback = stop,
  })

  render()
  pcall(vim.cmd, "redraw!")

  timer:start(
    120,
    120,
    vim.schedule_wrap(function()
      tick = tick % #frames + 1
      render()
    end)
  )

  -- 防御性超时：Neogit 若没有发出完成事件，也不要让 timer 永久挂着。
  vim.defer_fn(stop, 60000)
  return stop
end

return M
