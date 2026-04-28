-- nvim-treesitter main 分支：API 与 master 分支完全不同
--   * setup 仅接受 install_dir 等少量选项，ensure_installed/auto_install 无效
--   * 需要显式调用 install() 安装解析器
--   * Neovim 0.11+ 已自动为已安装 parser 的 filetype 启用高亮
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
  -- 补齐常见构建/工程文件 parser；只按语言安装，不写项目专用 filetype 规则。
  "cmake",
  "gn",
  "ninja",
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

local function configured_parser_lookup()
  -- 把 parser 列表转成集合，FileType autocmd 可以快速判断是否需要启动 Treesitter。
  local lookup = {}

  for _, lang in ipairs(ensure_installed) do
    lookup[lang] = true
  end

  return lookup
end

local parsers = configured_parser_lookup()

local function start_configured_parser(bufnr)
  local filetype = vim.bo[bufnr].filetype
  if filetype == "" then
    return
  end

  local lang = vim.treesitter.language.get_lang(filetype) or filetype
  if not parsers[lang] then
    return
  end

  -- nvim-treesitter main 分支更接近 parser 管理器；这里显式启动高亮，
  -- 避免大项目里只落到传统 syntax 的零散高亮状态。
  pcall(vim.treesitter.start, bufnr, lang)
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

    -- main 分支不会再用旧版 highlight.enable 配置，这里按 filetype 显式启动已配置 parser。
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("ConfigTreesitterStart", { clear = true }),
      callback = function(event)
        start_configured_parser(event.buf)
      end,
      desc = "Start configured Treesitter parsers",
    })

    vim.schedule(function()
      -- 启动后补装缺失 parser，再尝试给当前 buffer 启动高亮。
      install_missing_parsers()
      start_configured_parser(vim.api.nvim_get_current_buf())
    end)
  end,
}
