require("util.keymap_conflicts").setup()

-- 加载顺序：options → keymaps → autocmds → lazy
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")

-- Neovide 配置
if vim.g.neovide then
  require("config.neovide")
end
