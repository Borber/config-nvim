local M = {}

-- 复用 Noice LSP progress 的轻量盲文帧，让 Neogit 占位动画和消息系统气质一致。
local frames = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local message = "Loading Neogit..."
local ns = vim.api.nvim_create_namespace("ConfigNeogitLoading")
local border = require("util.float").borderchars()
local active

-- Noice 很晚才加载时也能渲染；等 Noice 高亮存在后再自动贴近它的 progress 配色。
local function highlight(group, fallback)
  return vim.fn.hlexists(group) == 1 and group or fallback
end

-- 按 Noice progress 的思路保留分段文本，方便分别给 spinner 和文案上色。
local function content_chunks(tick)
  return {
    { frames[tick] .. " ", highlight("NoiceLspProgressSpinner", "Constant") },
    { message, highlight("NoiceLspProgressTitle", "NonText") },
  }
end

-- buffer 内容只能写纯文本，高亮信息单独通过 extmark 套回去。
local function join_chunks(chunks)
  local text = {}

  for _, chunk in ipairs(chunks) do
    table.insert(text, chunk[1])
  end

  return table.concat(text)
end

-- 返回下一个列位置，调用方可以连续给多个片段铺高亮。
local function add_highlight(buf, row, start_col, text, group)
  if text == "" then
    return start_col
  end

  local end_col = start_col + #text
  vim.api.nvim_buf_set_extmark(buf, ns, row, start_col, {
    end_col = end_col,
    hl_group = group,
  })

  return end_col
end

local function stop_active()
  -- 同一时间只允许一个 loading 占位；停止时恢复窗口选项、timer 和临时 autocmd。
  if not active then
    return
  end

  local current = active
  active = nil

  if current.buf and vim.api.nvim_buf_is_valid(current.buf) then
    vim.api.nvim_buf_clear_namespace(current.buf, ns, 0, -1)
  end

  if vim.api.nvim_win_is_valid(current.win) then
    vim.api.nvim_set_option_value("signcolumn", current.signcolumn, { win = current.win })
  end

  current.timer:stop()
  if not current.timer:is_closing() then
    current.timer:close()
  end

  local ok, err = pcall(vim.api.nvim_del_augroup_by_id, current.group)
  if not ok then
    vim.notify("Failed to clear Neogit loading autocmds: " .. tostring(err), vim.log.levels.ERROR)
  end
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
  local tick = 1

  active = { buf = buf, group = group, signcolumn = signcolumn, timer = timer, win = target_win }
  -- loading 期间隐藏 signcolumn，让居中文案不会被左侧列挤歪。
  vim.api.nvim_set_option_value("signcolumn", "no", { win = target_win })

  -- 生成居中占位内容；窗口太小时退回无边框单行，避免布局被边框撑坏。
  local function centered_box(chunks)
    local height = math.max(1, vim.api.nvim_win_get_height(target_win))
    local width = math.max(1, vim.api.nvim_win_get_width(target_win))
    local lines = vim.fn["repeat"]({ "" }, height)

    if height < 3 or width < 12 then
      local line = join_chunks(chunks)
      local row = math.max(1, math.ceil(height / 2))
      local padding = math.max(0, math.floor((width - vim.fn.strdisplaywidth(line)) / 2))
      lines[row] = string.rep(" ", padding) .. line

      return lines, {
        middle = row - 1,
        content_col = padding,
        chunks = chunks,
      }
    end

    local content = join_chunks(chunks)
    local inner_width = vim.fn.strdisplaywidth(content) + 2
    local top = border[1] .. string.rep(border[2], inner_width) .. border[3]
    local middle = border[8] .. " " .. content .. " " .. border[4]
    local bottom = border[7] .. string.rep(border[6], inner_width) .. border[5]
    local row = math.max(1, math.min(math.ceil(height / 2) - 1, height - 2))
    local padding = math.max(0, math.floor((width - vim.fn.strdisplaywidth(top)) / 2))
    local prefix = string.rep(" ", padding)

    lines[row] = prefix .. top
    lines[row + 1] = prefix .. middle
    lines[row + 2] = prefix .. bottom

    return lines,
      {
        top = row - 1,
        middle = row,
        bottom = row + 1,
        prefix_col = #prefix,
        content_col = #prefix + #border[8] + 1,
        top_line = top,
        middle_line = middle,
        bottom_line = bottom,
        chunks = chunks,
      }
  end

  -- 每次重绘都先清理旧 extmark，避免 spinner 切帧后残留旧高亮范围。
  local function apply_highlights(layout)
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    if layout.top then
      add_highlight(buf, layout.top, layout.prefix_col, layout.top_line, "FloatBorder")
      add_highlight(buf, layout.middle, layout.prefix_col, border[8], "FloatBorder")
      add_highlight(buf, layout.middle, layout.prefix_col + #layout.middle_line - #border[4], border[4], "FloatBorder")
      add_highlight(buf, layout.bottom, layout.prefix_col, layout.bottom_line, "FloatBorder")
    end

    local col = layout.content_col
    for _, chunk in ipairs(layout.chunks) do
      col = add_highlight(buf, layout.middle, col, chunk[1], chunk[2])
    end
  end

  local function render()
    -- timer 回调可能晚于窗口关闭或下一次 Neogit 打开，先确认仍是当前 active 实例。
    if not active or active.timer ~= timer then
      return
    end

    if not vim.api.nvim_win_is_valid(target_win) or not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
      stop_active()
      return
    end

    local chunks = content_chunks(tick)
    local lines, layout = centered_box(chunks)
    local readonly = vim.api.nvim_get_option_value("readonly", { buf = buf })
    -- Neogit buffer 通常是不可改的；短暂打开 modifiable 只用于替换占位内容。
    vim.api.nvim_set_option_value("readonly", false, { buf = buf })
    vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    apply_highlights(layout)
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
  vim.cmd("redraw!")

  timer:start(
    80,
    80,
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
