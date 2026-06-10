local function yank_history()
  local is_visual = vim.fn.mode() == "v" or vim.fn.mode() == "V"
  if is_visual then
    vim.cmd([[execute "normal! \<esc>"]])
  end

  local history = {}
  for index, value in pairs(require("yanky.history").all()) do
    value.history_index = index
    history[index] = value
  end

  require("util.fzf_picker").select(history, {
    prompt = "Yank history",
    format_item = function(item)
      return item.regcontents and item.regcontents:gsub("\n", "\\n") or ""
    end,
  }, require("yanky.picker").actions.put("p", is_visual))
end

return {
  "gbprod/yanky.nvim",
  event = "VeryLazy",
  init = function()
    require("util.sqlite").configure_clib()
  end,
  keys = {
    {
      "<leader>p",
      yank_history,
      desc = "Yank history",
    },
  },
  dependencies = {
    "kkharji/sqlite.lua",
    "ibhagwan/fzf-lua",
  },
  opts = {
    ring = {
      history_length = 10000,
      storage = "sqlite",
      storage_path = vim.fn.stdpath("data") .. "/databases/yanky.db",
    },
    highlight = {
      on_put = true,
      on_yank = true,
      timer = 200,
    },
  },
  config = function(_, opts)
    require("yanky").setup(opts)

    vim.keymap.set({ "n", "x" }, "p", "<Plug>(YankyPutAfter)", { silent = true })
    vim.keymap.set({ "n", "x" }, "P", "<Plug>(YankyPutBefore)", { silent = true })
    vim.keymap.set("n", "<C-p>", "<Plug>(YankyPreviousEntry)", { silent = true })
    vim.keymap.set("n", "<C-n>", "<Plug>(YankyNextEntry)", { silent = true })
  end,
}
