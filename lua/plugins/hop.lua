return {
  "wsdjeg/hop.nvim",
  keys = {
    {
      "s",
     "<cmd>HopWord<cr>",
      mode = { "n", "x", "o" },
      desc = "Hop hint words",
      silent = true,
    }
  },
  opts = {
    keys = "werasdfcvjlk",
    jump_on_sole_occurrence = true,
    dim_unmatched = false
  },
}