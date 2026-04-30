return {
  "sindrets/diffview.nvim",
  opts = function()
    -- 三个 Diffview 面板都用同一个关闭动作，保持 <C-x> 的退出手感一致。
    local close_diffview = function()
      require("diffview").close()
    end

    return {
      hooks = {
        diff_buf_read = function()
          -- diff 行按原始宽度展示更容易对齐，避免 wrap 破坏 hunk 阅读。
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
