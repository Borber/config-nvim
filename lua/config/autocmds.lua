-- ============================================
-- 全局 autocmd
-- ============================================
local augroup = vim.api.nvim_create_augroup
local buffer_util = require("util.buffer")

-- 类似 FilePost，但额外要求 UI 已经进入，避免启动页/空 buffer 过早触发文件型 UI 插件。
local file_post_group = "config_file_post"
local file_post_fired = false
local ui_entered = false

local function fire_config_file_post(bufnr)
  if file_post_fired or not ui_entered or not buffer_util.is_normal_file(bufnr) then
    return
  end

  file_post_fired = true
  vim.g.config_file_posted = true

  -- 只在首个真实文件出现后广播一次，给 gitsigns/todo-comments 这类文件型插件做延后加载。
  vim.api.nvim_exec_autocmds("User", {
    pattern = "ConfigFilePost",
    modeline = false,
    data = { buf = bufnr },
  })

  pcall(vim.api.nvim_del_augroup_by_name, file_post_group)
end

vim.api.nvim_create_autocmd({ "UIEnter", "BufReadPost", "BufNewFile" }, {
  group = augroup(file_post_group, { clear = true }),
  callback = function(event)
    if event.event == "UIEnter" then
      ui_entered = true
    end

    fire_config_file_post(event.buf)
  end,
  desc = "Emit ConfigFilePost after UI enters a real file buffer",
})

local function strip_carriage_returns(bufnr)
  local target_bufnr = buffer_util.normal_writable(bufnr)
  if target_bufnr == nil then
    return
  end

  if vim.bo[target_bufnr].binary then
    return
  end

  local view = vim.fn.winsaveview()

  vim.api.nvim_buf_call(target_bufnr, function()
    vim.cmd([[keepjumps keeppatterns %s/\r//ge]])
  end)

  vim.fn.winrestview(view)
end

-- 仅对“正常文件 buffer”执行自动保存：
-- - 必须是有效 buffer
-- - 不能是 terminal/help/quickfix 等特殊 buftype
-- - 必须可修改、非只读、且当前确实有未保存改动
-- - 必须已经有文件名，避免把无名临时 buffer 强行写盘
local function autosave_normal_buffer(bufnr)
  local target_bufnr = buffer_util.normal_writable_file(bufnr)
  if target_bufnr == nil then
    return
  end

  if not vim.bo[target_bufnr].modified then
    return
  end

  local ok, err = pcall(vim.api.nvim_buf_call, target_bufnr, function()
    -- 用 :update 而不是 :write：只有内容真的变更时才写盘。
    -- silent 避免在频繁切窗/失焦时打扰命令行区域。
    vim.cmd("silent update")
  end)

  if not ok then
    vim.notify("Autosave failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

-- 严格 autosave：覆盖几类最常见的“离开当前编辑上下文”场景
-- - InsertLeave：退出插入模式时保存
-- - BufLeave：离开当前 buffer（含切到 terminal / 切窗口 / 切别的文件）时保存
-- - FocusLost：Neovim / Neovide 失焦时保存
-- - VimLeavePre：退出前再尽量保存一次
vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "FocusLost", "VimLeavePre" }, {
  group = augroup("config_autosave", { clear = true }),
  callback = function(event)
    autosave_normal_buffer(event.buf)
  end,
  desc = "Autosave normal file buffers",
})

-- 清理混合换行/残留 CR 字符，避免行尾显示 ^M。
vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePre" }, {
  group = augroup("config_strip_carriage_returns", { clear = true }),
  callback = function(event)
    strip_carriage_returns(event.buf)
  end,
  desc = "Strip stray carriage returns from file buffers",
})

-- 打开内置终端时关闭行号/sign 并立即进入插入模式
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup("config_term_open", { clear = true }),
  callback = function(event)
    vim.wo.number = false
    vim.wo.relativenumber = false
    vim.wo.signcolumn = "no"
    vim.bo[event.buf].buflisted = false
    vim.cmd("startinsert")
  end,
  desc = "Prepare terminal buffers",
})
