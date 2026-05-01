return {
  "stevearc/conform.nvim",
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "never" })
      end,
      mode = { "n", "v" },
      desc = "Format",
    },
  },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      rust = { "rustfmt" },
      javascript = { "prettierd" },
      typescript = { "prettierd" },
      json = { "prettierd" },
      markdown = { "prettierd" },
      sh = { "shfmt" },
    },
    default_format_opts = {
      -- 不回退到 LSP；formatter 缺失时让 conform 直接通知用户修复工具链。
      lsp_format = "never",
    },
    notify_on_error = true,
    notify_no_formatters = true,
  },
}
