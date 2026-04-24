-- 加载顺序：options → keymaps → autocmds → lazy
require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")

-- Neovide 专属配置
if vim.g.neovide then
  require("config.neovide")
end
