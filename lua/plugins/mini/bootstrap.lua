local M = {}

local configured = false
local editing_configured = false
local icons_configured = false

local function setup_icons()
  if icons_configured then
    return
  end

  icons_configured = true

  -- 图标：作为 nvim-web-devicons 的替代；UI ready 后再加载，避免 starter 首屏加载图标系统。
  require("mini.icons").setup()
  MiniIcons.mock_nvim_web_devicons()
end

local function setup_editing_modules()
  if editing_configured then
    return
  end

  editing_configured = true

  require("mini.pairs").setup()
  require("mini.align").setup()
  require("plugins.mini.trailspace").setup()

  require("mini.indentscope").setup({
    symbol = require("libs.icons").basic.indent,
    draw = {
      delay = 50,
      animation = require("mini.indentscope").gen_animation.none(),
    },
    options = {
      try_as_border = true,
    },
  })

  -- indentscope 对特殊 buffer 无意义，按 filetype/buftype 禁用。
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ConfigIndentscopeDisable", { clear = true }),
    pattern = { "help", "lazy", "mason", "ministarter", "Outline", "Trouble", "toggleterm", "neogit*" },
    callback = function()
      vim.b.miniindentscope_disable = true
    end,
  })

  require("mini.surround").setup({
    mappings = {
      add = "msa",
      delete = "msd",
      find = "msf",
      find_left = "msF",
      highlight = "msh",
      replace = "msr",
    },
  })
end

local function setup_editing_autocmds(lifecycle)
  local group = vim.api.nvim_create_augroup("ConfigMiniEditing", { clear = true })

  -- Starter 首屏不需要编辑增强；进入真实文件或开始输入时再启用，保留日常编辑手感。
  lifecycle.once("file_post", function()
    setup_editing_modules()
  end, {
    group = group,
    desc = "Load editing mini modules after first real file",
  })

  vim.api.nvim_create_autocmd("InsertEnter", {
    group = group,
    once = true,
    callback = setup_editing_modules,
    desc = "Load editing mini modules before inserting text",
  })
end

local function setup_keymaps()
  vim.keymap.set("n", "<leader>e", function()
    require("plugins.mini.files").toggle()
  end, {
    desc = "Explorer",
    silent = true,
  })

  vim.keymap.set("n", "<leader>X", function()
    require("mini.bufremove").delete(0, true)
  end, {
    desc = "Force delete buffer",
    silent = true,
  })
end

local function setup_commands()
  vim.api.nvim_create_user_command("Starter", function()
    require("plugins.mini.starter").open()
  end, { desc = "Open starter", force = true })
end

function M.setup()
  local lifecycle = require("config.lifecycle")
  lifecycle.setup()

  if configured then
    return
  end

  configured = true

  local function setup_ui_modules()
    setup_icons()
  end

  lifecycle.once("ui_ready", function()
    setup_ui_modules()
  end, {
    group = vim.api.nvim_create_augroup("ConfigMiniUi", { clear = true }),
    desc = "Load mini UI compatibility helpers",
  })

  setup_editing_autocmds(lifecycle)

  local sessions = require("plugins.mini.sessions")
  sessions.setup()
  require("config.recent_projects").setup()

  setup_keymaps()
  setup_commands()

  if vim.fn.argc() == 0 and not sessions.has_current() then
    require("plugins.mini.starter").setup({ autoopen = true })
  end
end

return M
