return {
  "sindrets/diffview.nvim",
  cmd = {
    "DiffviewClose",
    "DiffviewFileHistory",
    "DiffviewFocusFiles",
    "DiffviewLog",
    "DiffviewOpen",
    "DiffviewRefresh",
    "DiffviewToggleFiles",
  },
  opts = function()
    return {
      hooks = {
        diff_buf_read = function()
          -- diff 行按原始宽度展示更容易对齐，避免 wrap 破坏 hunk 阅读。
          vim.opt_local.wrap = false
        end,
      },
    }
  end,
}
