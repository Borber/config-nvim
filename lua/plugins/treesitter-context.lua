local disabled_filetypes = {
  help = true,
  man = true,
  ministarter = true,
  qf = true,
}

local function should_attach(bufnr)
  if vim.bo[bufnr].buftype ~= "" then
    return false
  end

  return not disabled_filetypes[vim.bo[bufnr].filetype]
end

return {
  "nvim-treesitter/nvim-treesitter-context",
  event = "User ConfigFilePost",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  keys = {
    {
      "[c",
      function()
        require("treesitter-context").go_to_context(vim.v.count1)
      end,
      desc = "Jump to context",
    },
  },
  opts = {
    enable = true,
    max_lines = 3,
    min_window_height = 0,
    line_numbers = true,
    multiline_threshold = 20,
    trim_scope = "outer",
    mode = "cursor",
    separator = nil,
    zindex = 20,
    on_attach = should_attach,
  },
}
