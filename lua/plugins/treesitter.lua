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

local function install_configured_parsers()
  require("nvim-treesitter").install(ensure_installed)
end

local function update_configured_parsers()
  require("nvim-treesitter").update(ensure_installed)
end

local function install_missing_parsers()
  local installed = {}

  for _, lang in ipairs(require("nvim-treesitter").get_installed()) do
    installed[lang] = true
  end

  local missing = vim.tbl_filter(function(lang)
    return not installed[lang]
  end, ensure_installed)

  if #missing > 0 then
    require("nvim-treesitter").install(missing)
  end
end

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  lazy = false,
  build = update_configured_parsers,
  config = function()
    require("nvim-treesitter").setup()

    vim.api.nvim_create_user_command("TSInstallConfigParsers", install_configured_parsers, {
      desc = "Install configured Treesitter parsers",
      force = true,
    })

    vim.schedule(install_missing_parsers)

    -- 为已安装的语言启用高亮
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("ConfigTreesitterStart", { clear = true }),
      pattern = ensure_installed,
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
