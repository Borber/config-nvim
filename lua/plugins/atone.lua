local function data_path(...)
  return vim.fs.joinpath(vim.fn.stdpath("data"), ...)
end

return {
  "XXiaoA/atone.nvim",
  cmd = "Atone",
  keys = {
    {
      "<leader>ut",
      "<Cmd>Atone toggle<CR>",
      desc = "Undo tree",
      silent = true,
    },
  },
  init = function()
    vim.fn.mkdir(data_path("atone"), "p")
  end,
  opts = {
    layout = {
      direction = "left",
      width = "adaptive",
    },
    marks = {
      persist = true,
      persist_path = data_path("atone", "marks.json"),
      finders = { "fzf-lua", "builtin" },
    },
    auto_attach = {
      enabled = true,
      excluded_ft = {
        "NeogitCommitMessage",
        "NeogitPopup",
        "NeogitStatus",
        "Outline",
        "Trouble",
        "lazy",
        "mason",
        "minifiles",
        "ministarter",
        "neogitstatus",
        "noice",
        "notify",
        "qf",
        "toggleterm",
      },
    },
    ui = {
      border = require("util.float").border,
    },
  },
}
