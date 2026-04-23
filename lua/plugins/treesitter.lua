-- nvim-treesitter main 分支：API 与 master 分支完全不同
--   * setup 仅接受 install_dir 等少量选项，ensure_installed/auto_install 无效
--   * 需要显式调用 install() 安装解析器
--   * 高亮不自动启用，需要 FileType autocmd 里调用 vim.treesitter.start()
--   * 不支持懒加载（必须 lazy = false）
local ensure_installed = {
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
}

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = ":TSUpdate",
  config = function()
    require("nvim-treesitter").setup()

    -- install() 对已安装解析器是 no-op，异步执行
    require("nvim-treesitter").install(ensure_installed)

    -- 为已安装的语言启用高亮
    vim.api.nvim_create_autocmd("FileType", {
      pattern = ensure_installed,
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
