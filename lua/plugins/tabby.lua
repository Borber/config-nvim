local function modified_tab_buffers(tabpage)
  local buffers = {}
  local seen = {}
  local has_unnamed = false

  -- 一个 tab 里可能有多个窗口指向同一个 buffer，所以用 seen 去重。
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
    local buf = vim.api.nvim_win_get_buf(win)

    if not seen[buf] and vim.bo[buf].buftype == "" and vim.bo[buf].modified then
      seen[buf] = true

      if vim.api.nvim_buf_get_name(buf) == "" then
        has_unnamed = true
      else
        table.insert(buffers, buf)
      end
    end
  end

  return buffers, has_unnamed
end

local function write_buffers(buffers)
  for _, buf in ipairs(buffers) do
    local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd("write")
    end)

    if not ok then
      vim.notify(err, vim.log.levels.WARN)
      return false
    end
  end

  return true
end

local function close_tab()
  local buffers, has_unnamed = modified_tab_buffers(0)

  if #buffers == 0 and not has_unnamed then
    vim.cmd("tabclose")
    return
  end

  -- 有文件名的改动 buffer 可以直接写盘；无名 buffer 必须询问，
  -- 否则 tabclose! 会让用户还没命名的新内容消失。
  if #buffers > 0 and not write_buffers(buffers) then
    return
  end

  if not has_unnamed then
    vim.cmd("tabclose")
    return
  end

  local choice = vim.fn.confirm(
    "Current tab contains unnamed modified buffers. Force close it?",
    "&Force close\n&Cancel",
    2
  )

  if choice == 1 then
    vim.cmd("tabclose!")
  end
end

return {
  "nanozuki/tabby.nvim",
  lazy = false,
  init = function()
    vim.o.showtabline = 2

    vim.keymap.set("n", "<leader>tn", "<Cmd>tabnew<CR>", {
      desc = "New tab",
      silent = true,
    })
    vim.keymap.set("n", "<leader>tx", close_tab, {
      desc = "Close tab",
      silent = true,
    })
  end,
  opts = {
    preset = "tab_only",
    option = {
      tab_name = {
        name_fallback = function(tabpage)
          return require("util.main_file").tab_name(tabpage)
        end,
      },
      nerdfont = true,
      buf_name = {
        mode = "unique",
      },
    },
  },
}
