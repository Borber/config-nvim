local M = {}

-- ============================================
-- 工具清单与检查
-- ============================================
M.server_commands = {
  lua_ls = "lua-language-server",
  rust_glancer = "rust-glancer",
  clangd = "clangd",
  ts_ls = "typescript-language-server",
  eslint = "vscode-eslint-language-server",
  jsonls = "vscode-json-language-server",
  bashls = "bash-language-server",
  taplo = "taplo",
}

local install_hints = {
  ["lua-language-server"] = ":MasonInstall lua-language-server",
  ["rust-glancer"] = "从 https://github.com/rust-glancer/rust-glancer/releases 安装正式版",
  clangd = "使用系统包管理器安装 clangd",
  ["typescript-language-server"] = "bun add --global typescript@6 typescript-language-server",
  ["vscode-eslint-language-server"] = "bun add --global vscode-langservers-extracted",
  ["vscode-json-language-server"] = "bun add --global vscode-langservers-extracted",
  ["bash-language-server"] = "bun add --global bash-language-server",
  taplo = ":MasonInstall taplo",
  stylua = ":MasonInstall stylua",
  rustfmt = "rustup component add rustfmt",
  prettierd = "bun add --global @fsouza/prettierd",
  shfmt = ":MasonInstall shfmt",
  shellcheck = ":MasonInstall shellcheck",
  node = "安装 Node.js 并加入 PATH",
  cargo = "通过 rustup 安装 Rust 工具链",
  ["tree-sitter"] = "使用系统包管理器安装 tree-sitter CLI",
  cc = "安装 C 编译器并提供 cc 命令",
}

local warned = {}

function M.available(command, root)
  if root and vim.fn.executable(vim.fs.joinpath(root, "node_modules", ".bin", command)) == 1 then
    return true
  end

  return vim.fn.executable(command) == 1
end

function M.warn_missing(command)
  if warned[command] then
    return
  end

  warned[command] = true
  vim.schedule(function()
    vim.notify(
      ("缺少语言工具 %s，已跳过启动。\n%s\n可运行 :ConfigToolsCheck 检查全部依赖。"):format(
        command,
        install_hints[command] or "请安装该工具并加入 Neovim 的 PATH"
      ),
      vim.log.levels.WARN
    )
  end)
end

function M.check()
  local results = {}

  for _, command in ipairs(vim.fn.sort(vim.tbl_keys(install_hints))) do
    results[#results + 1] = {
      command = command,
      available = M.available(command),
      install = install_hints[command],
    }
  end

  return results
end

-- ============================================
-- 环境与手动入口
-- ============================================
function M.setup()
  local data = vim.fn.stdpath("data")
  local tools_bin = vim.fs.joinpath(data, "tools", "bin")
  local mason_bin = vim.fs.joinpath(data, "mason", "bin")
  local separator = package.config:sub(1, 1) == "\\" and ";" or ":"
  local paths = vim.env.PATH and vim.split(vim.env.PATH, separator, { plain = true }) or {}
  if not vim.tbl_contains(paths, tools_bin) then
    table.insert(paths, 1, tools_bin)
  end
  if not vim.tbl_contains(paths, mason_bin) then
    table.insert(paths, mason_bin)
  end
  vim.env.PATH = table.concat(paths, separator)

  vim.api.nvim_create_user_command("ConfigToolsCheck", function()
    local lines = { "语言工具检查（Neovim PATH）" }
    local missing = false

    for _, result in ipairs(M.check()) do
      if result.available then
        lines[#lines + 1] = "OK  " .. result.command
      else
        missing = true
        lines[#lines + 1] = ("缺失  %s：%s"):format(result.command, result.install)
      end
    end

    vim.notify(table.concat(lines, "\n"), missing and vim.log.levels.WARN or vim.log.levels.INFO)
  end, { desc = "Check configured language tools", force = true })
end

return M
