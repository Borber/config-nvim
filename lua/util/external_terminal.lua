local M = {}

local function ps_quote(value)
  -- Start-Process 的 -ArgumentList 走 PowerShell 字符串，单引号要写成两个单引号。
  return "'" .. tostring(value):gsub("'", "''") .. "'"
end

local function os_name()
  local uv = vim.uv or vim.loop
  return uv.os_uname().sysname
end

local function windows_terminal()
  -- Windows Terminal 在不同安装方式下可能暴露 wt.exe 或 wt 两种命令名。
  if vim.fn.executable("wt.exe") == 1 then
    return "wt.exe"
  end

  if vim.fn.executable("wt") == 1 then
    return "wt"
  end
end

local function launch_windows(args)
  local terminal = windows_terminal()

  if terminal == nil then
    vim.notify("Windows Terminal (wt.exe) not found in PATH", vim.log.levels.ERROR)
    return false
  end

  local argument_list = {}

  for _, arg in ipairs(args) do
    table.insert(argument_list, ps_quote(arg))
  end

  -- jobstart 直接启动 wt 时参数转义容易被多层 shell 吃掉；
  -- 这里让 pwsh 调 Start-Process，把工作目录等参数作为 ArgumentList 传入。
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

local function launch_macos(cwd)
  if vim.fn.executable("open") ~= 1 then
    vim.notify("macOS open command not found in PATH", vim.log.levels.ERROR)
    return false
  end

  vim.fn.jobstart({ "open", "-a", "Terminal", cwd }, { detach = true })

  return true
end

function M.open_shell(cwd)
  -- 默认在当前工作目录打开外部终端，保留编辑器内置终端给短任务使用。
  cwd = cwd or vim.fn.getcwd()

  local system = os_name()

  if system == "Windows_NT" then
    return launch_windows({ "-d", cwd })
  end

  if system == "Darwin" then
    return launch_macos(cwd)
  end

  vim.notify("external_terminal: unsupported OS " .. system, vim.log.levels.ERROR)
  return false
end

return M
