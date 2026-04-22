-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
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

-- Make sure to setup `mapleader` and `maplocalleader` before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Setup lazy.nvim
require("lazy").setup({
  spec = {
	{ "sevenc-nanashi/neov-ime.nvim" },

  -- ========================================
  -- Markdown 编辑增强
  -- ========================================
  {
    "yousefhadder/markdown-plus.nvim",
    ft = "markdown",
    opts = {},
    -- 默认快捷键（<localleader> 默认是 \）：
    -- 列表: Enter 自动续行, Tab/S-Tab 缩进
    -- 格式化: \mb 加粗, \mi 斜体, \ms 删除线, \m` 行内代码
    -- 标题: \m1~\m6 设置标题级别, \mk/\mj 升/降级
    -- TOC: \mt 生成目录
    -- Checkbox: \mx 切换勾选
  },

  },
  -- Configure any other settings here. See the documentation for more details.
  -- colorscheme that will be used when installing plugins.
  install = { colorscheme = { "habamax" } },
  -- automatically check for plugin updates
  checker = { enabled = true },
})
