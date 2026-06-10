-- 加载顺序：options → keymaps → autocmds → lazy
require("config.options")
require("config.keymaps")
require("config.notes_commands").setup()
require("config.autocmds")
require("config.lazy")
