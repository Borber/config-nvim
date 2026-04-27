return {
  "stevearc/conform.nvim",
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = { "n", "v" },
      desc = "Format",
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      rust = { "rustfmt" },
      -- prettierd 更快，prettier 作为兜底；stop_after_first 避免同一文件格式化两次。
      javascript = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      json = { "prettierd", "prettier", stop_after_first = true },
      markdown = { "prettierd", "prettier", stop_after_first = true },
      sh = { "shfmt" },
    },
    default_format_opts = {
      -- 没有外部 formatter 时回退到 LSP format，保证 <leader>cf 尽量总是可用。
      lsp_format = "fallback",
    },
  },
}
