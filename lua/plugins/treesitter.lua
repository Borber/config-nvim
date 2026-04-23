return {
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  opts = {
    auto_install = true,
    ensure_installed = {
      "markdown",
      "markdown_inline",
      "html",
      "lua",
      "vim",
      "vimdoc",
      "rust",
      "toml",
      "c",
      "cpp",
      "bash",
      "json",
      "typescript",
      "javascript",
    },
  },
}
