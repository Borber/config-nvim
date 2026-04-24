local M = {}

local function ps_quote(value)
  return "'" .. tostring(value):gsub("'", "''") .. "'"
end

local function windows_terminal()
  if vim.fn.executable("wt.exe") == 1 then
    return "wt.exe"
  end

  if vim.fn.executable("wt") == 1 then
    return "wt"
  end
end

local function launch(args)
  local terminal = windows_terminal()

  if terminal == nil then
    vim.notify("Windows Terminal (wt.exe) not found in PATH", vim.log.levels.ERROR)
    return false
  end

  local argument_list = {}

  for _, arg in ipairs(args) do
    table.insert(argument_list, ps_quote(arg))
  end

  vim.fn.jobstart({
    "pwsh.exe",
    "-NoLogo",
    "-NoProfile",
    "-Command",
    "Start-Process -FilePath "
      .. ps_quote(terminal)
      .. " -ArgumentList @("
      .. table.concat(argument_list, ", ")
      .. ")",
  }, { detach = true })

  return true
end

function M.open_shell(cwd)
  cwd = cwd or vim.fn.getcwd()

  return launch({ "-d", cwd })
end

return M