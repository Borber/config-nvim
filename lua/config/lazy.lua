-- Bootstrap lazy.nvim：
-- 如果插件管理器还没安装，就自动拉取 stable 分支，保证新环境也能直接启动。
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

if vim.g.lazy_did_setup then
  -- :R 会重新 source init.lua；Lazy 已初始化时只刷新插件规格，避免重复 setup 警告。
  local ok, reloader = pcall(require, "lazy.manage.reloader")
  if ok then
    reloader.reload({
      {
        file = vim.env.MYVIMRC or vim.fs.joinpath(vim.fn.stdpath("config"), "init.lua"),
        what = "changed",
      },
    })
  end

  return
end

require("lazy").setup({
  spec = {
    -- 统一从 lua/plugins/ 目录加载插件规格，避免 init.lua 变得臃肿。
    { import = "plugins" },
  },
  -- 首次安装时优先启用 rose-pine；habamax 是 Neovim 自带兜底主题。
  install = { colorscheme = { "rose-pine", "habamax" } },
  -- 关闭后台检查更新和配置变更通知，减少编辑时的消息打扰。
  checker = { enabled = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "man",
        "matchit",
        "net",
        "rplugin",
        "shada",
        "spellfile",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "netrwPlugin", -- 已改用 mini.files
      },
    },
  },
})
