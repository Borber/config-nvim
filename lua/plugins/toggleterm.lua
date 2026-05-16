local patch = require("patches.toggleterm_open_split")

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  dependencies = { "ibhagwan/fzf-lua" },
  cmd = { "ToggleTerm", "TermExec", "TermSelect", "ToggleTermSetName" },
  keys = {
    { "<leader>tt", patch.toggle_default, desc = "Toggle terminal", mode = "n" },
    { "<leader>th", patch.open_new("horizontal"), desc = "New terminal (horizontal)", mode = "n" },
    { "<leader>tv", patch.open_new("vertical"), desc = "New terminal (vertical)", mode = "n" },
    { "<leader>to", patch.pick_terminal, desc = "Pick terminal", mode = "n" },
    { "<leader>tr", patch.rename_terminal, desc = "Rename terminal", mode = "n" },
  },
  opts = {
    size = function(term)
      -- 终端尺寸随窗口缩放，但保留最低可用尺寸。
      if term.direction == "horizontal" then
        return math.max(12, math.floor(vim.o.lines * 0.3))
      end
      if term.direction == "vertical" then
        return math.max(30, math.floor(vim.o.columns * 0.3))
      end
    end,
    shade_terminals = false,
    persist_mode = false,
    persist_size = true,
    start_in_insert = true,
    auto_scroll = true,
    hide_numbers = true,
    insert_mappings = false,
    close_on_exit = false,
    on_open = function()
      vim.cmd("startinsert")
    end,
  },
}
