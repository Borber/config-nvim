return {
  "sindrets/diffview.nvim",
  opts = function()
    local close_diffview = function()
      require("diffview").close()
    end

    return {
      hooks = {
        diff_buf_read = function()
          vim.opt_local.wrap = false
        end,
      },
      keymaps = {
        view = {
          { "n", "<C-x>", close_diffview, { desc = "Close Diffview" } },
        },
        file_panel = {
          { "n", "<C-x>", close_diffview, { desc = "Close Diffview" } },
        },
        file_history_panel = {
          { "n", "<C-x>", close_diffview, { desc = "Close Diffview" } },
        },
      },
    }
  end,
}
