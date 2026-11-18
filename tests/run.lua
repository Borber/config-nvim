local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local scripts = vim.fn.globpath(repo .. "/tests/headless", "*.lua", false, true)
table.sort(scripts)
assert(#scripts > 0, "No headless tests found")

local failed = 0
for _, script in ipairs(scripts) do
  -- 每个脚本独立进程，隔离 package.loaded、autocmd 和环境变量；-l 保证 Lua 错误返回非零。
  local result = vim
    .system({ vim.v.progpath, "--headless", "-u", "NONE", "-i", "NONE", "-n", "-l", script }, {
      cwd = repo,
      text = true,
    })
    :wait(30000)
  local name = vim.fn.fnamemodify(script, ":t")
  if result.code == 0 then
    print("ok - " .. name)
  else
    failed = failed + 1
    print("not ok - " .. name .. " (exit " .. result.code .. ")")
    print(vim.trim((result.stdout or "") .. "\n" .. (result.stderr or "")))
  end
end

if failed > 0 then
  error(string.format("%d/%d headless scripts failed", failed, #scripts), 0)
end
print(string.format("All %d headless scripts passed", #scripts))
