local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual: %s", message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local settings = require("lsp.servers.rust_analyzer").settings["rust-analyzer"]

assert_eq(settings.files.watcher, "server", "rust-analyzer should watch files itself")
assert_eq(settings.cargo.autoreload, true, "Cargo metadata should reload after manifest changes")
assert_eq(settings.check.command, "clippy", "Rust checks should keep using clippy")
assert_eq(settings.cargo.buildScripts.enable, true, "build script support should remain enabled")

print("headless rust-analyzer settings checks passed")
