local function hop_opts()
  local mode = vim.fn.mode(1)

  if mode == "v" or mode == "V" or mode == "\22" then
    return { extend_visual = true }
  end

  return {}
end

return {
  "smoka7/hop.nvim",
  version = "*",
  keys = {
    {
      "s",
      function()
        require("hop").hint_words(hop_opts())
      end,
      mode = { "n", "v" },
      desc = "Hop hint words",
      silent = true,
    },
    {
      "S",
      function()
        require("hop").hint_lines(hop_opts())
      end,
      mode = { "n", "v" },
      desc = "Hop hint lines",
      silent = true,
    },
  },
  opts = {},
}