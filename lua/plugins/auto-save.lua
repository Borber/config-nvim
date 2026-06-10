return {
  "okuuva/auto-save.nvim",
  version = "^1.0.0",
  cmd = "ASToggle",
  event = "VeryLazy",
  keys = {
    { "<leader>ua", "<Cmd>ASToggle<CR>", desc = "Toggle auto save" },
  },
  opts = {
    condition = function(bufnr)
      local bo = vim.bo[bufnr]
      return bo.buftype == "" and not bo.readonly and vim.api.nvim_buf_get_name(bufnr) ~= "" and bo.filetype ~= "gitcommit"
    end,
    debounce_delay = 500,
  },
}
