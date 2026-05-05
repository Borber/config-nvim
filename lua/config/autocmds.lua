-- ============================================
-- 全局 autocmd
-- ============================================
local augroup = vim.api.nvim_create_augroup
local buffer_util = require("libs.buffer")

local function emit_config_user_event(pattern, data)
  if pattern == "ConfigUiReady" then
    vim.g.config_ui_ready = true
  elseif pattern == "ConfigBackground" then
    vim.g.config_background_ready = true
  end

  vim.api.nvim_exec_autocmds("User", {
    pattern = pattern,
    modeline = false,
    data = data,
  })
end

vim.api.nvim_create_autocmd("User", {
  group = augroup("config_lazy_layers", { clear = true }),
  pattern = "VeryLazy",
  once = true,
  callback = function()
    emit_config_user_event("ConfigUiReady")

    vim.defer_fn(function()
      if vim.v.exiting ~= vim.NIL then
        return
      end

      emit_config_user_event("ConfigBackground")
    end, 800)
  end,
  desc = "Split VeryLazy follow-up work into ordered config layers",
})

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

  vim.api.nvim_del_augroup_by_name(file_post_group)
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
