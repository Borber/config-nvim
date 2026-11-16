local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)
vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/lazy/nvim-lspconfig")
vim.opt.updatecount = 0

local function assert_eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(("%s\nexpected: %s\nactual: %s"):format(message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local project = vim.fn.tempname()
vim.fn.mkdir(project .. "/.git", "p")
vim.fn.writefile({ "{}" }, project .. "/probe.json")
vim.cmd.edit(vim.fn.fnameescape(project .. "/probe.json"))

local notifications = {}
local available = {}
local commands = {}
local original_executable = vim.fn.executable
local original_notify = vim.notify
local original_rpc_start = vim.lsp.rpc.start

vim.fn.executable = function(command)
  if available[command] ~= nil then
    return available[command] and 1 or 0
  end
  return original_executable(command)
end
vim.notify = function(message)
  notifications[#notifications + 1] = message
end
vim.lsp.rpc.start = function(command)
  commands[#commands + 1] = command
  return {}
end

local ok, err = xpcall(function()
  local tools = require("config.tools")
  tools.setup()
  local registry = require("lsp")
  registry.configure()

  assert_eq(vim.tbl_contains(registry.names(), "rust_glancer"), true, "Rust should use Glancer")
  assert_eq(vim.tbl_contains(registry.names(), "rust_analyzer"), false, "RA should not remain enabled")
  for _, name in ipairs(registry.names()) do
    assert(tools.server_commands[name], "Enabled server must have a tool declaration: " .. name)
  end
  local glancer = vim.lsp.config.rust_glancer
  assert_eq(glancer.cmd, { "rust-glancer", "lsp" }, "Glancer should use the upstream launch command")
  assert_eq(glancer.init_options.diagnostics, {
    onStartup = true,
    onSave = true,
    command = "check",
  }, "Glancer should retain startup/save diagnostics via initialization options")
  assert_eq(require("lsp.servers.rust_glancer").settings, nil, "Glancer should not inherit RA settings")
  assert_eq(vim.lsp.config.jsonls.settings.json.validate.enable, true, "JSON validation should remain enabled after configuration is sent")

  local function try_start(name)
    local config = vim.lsp.config[name]
    config.root_dir(0, function(root)
      config.cmd({}, { root_dir = root })
    end)
    vim.wait(20)
  end

  available["vscode-json-language-server"] = false
  try_start("jsonls")
  try_start("jsonls")
  assert_eq(#commands, 0, "Missing JSON server must never reach the process launcher")
  assert_eq(#notifications, 1, "Missing server warning should only appear once")
  assert(not notifications[1]:find("transport.lua", 1, true), "Missing tool should not expose a transport exception")
  assert(notifications[1]:find("ConfigToolsCheck", 1, true), "Warning should expose the dependency check command")

  local local_json = vim.fs.joinpath(project, "node_modules", ".bin", "vscode-json-language-server")
  available[local_json] = true
  try_start("jsonls")
  assert_eq(commands[1], { local_json, "--stdio" }, "Project-local JSON server should work without a global install")

  available[local_json] = false
  available["vscode-json-language-server"] = true
  try_start("jsonls")
  assert_eq(commands[2], { "vscode-json-language-server", "--stdio" }, "Installing a missing server should allow the next start")

  available["typescript-language-server"] = false
  local local_ts = vim.fs.joinpath(project, "node_modules", ".bin", "typescript-language-server")
  available[local_ts] = true
  try_start("ts_ls")
  assert_eq(commands[3], { local_ts, "--stdio" }, "TypeScript root detection and local server lookup should remain intact")

  available["vscode-eslint-language-server"] = false
  try_start("eslint")
  assert_eq(#commands, 3, "ESLint should still skip projects without an ESLint config")
  assert_eq(#notifications, 1, "An irrelevant ESLint server should not produce a missing-tool warning")

  vim.fn.writefile({ "export default [];" }, project .. "/eslint.config.js")
  try_start("eslint")
  assert_eq(#commands, 3, "Missing ESLint server must never reach the process launcher")
  assert_eq(#notifications, 2, "Missing ESLint server should warn after the upstream root filter accepts it")

  available["clangd"] = false
  vim.bo.filetype = "cpp"
  vim.api.nvim_exec_autocmds("FileType", { buffer = 0 })
  vim.wait(20)
  assert_eq(#notifications, 3, "Table-form server commands should also report missing tools")

  available.prettierd = false
  local results = tools.check()
  local formatter_checked = false
  for _, result in ipairs(results) do
    if result.command == "prettierd" then
      formatter_checked = true
      assert_eq(result.available, false, "Dependency check should report missing formatters")
      assert(result.install:find("bun", 1, true), "Node tools should offer a bun installation command")
    end
  end
  assert_eq(formatter_checked, true, "Dependency check must cover Conform tools")
end, debug.traceback)

vim.fn.executable = original_executable
vim.notify = original_notify
vim.lsp.rpc.start = original_rpc_start
vim.fn.delete(project, "rf")

if not ok then
  error(err)
end

print("headless language tool checks passed")
