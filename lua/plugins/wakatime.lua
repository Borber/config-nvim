local function wakatime_home()
  if type(vim.env.WAKATIME_HOME) == "string" and vim.env.WAKATIME_HOME ~= "" then
    return vim.fn.expand(vim.env.WAKATIME_HOME)
  end

  return vim.fn.expand("~")
end

local function wakatime_config_file()
  return vim.fs.joinpath(wakatime_home(), ".wakatime.cfg")
end

local function trim(value)
  return vim.trim(tostring(value or ""))
end

local function read_setting(name)
  local path = wakatime_config_file()
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local in_settings = false
  for _, line in ipairs(vim.fn.readfile(path)) do
    -- 只读取 WakaTime 标准配置里的 [settings]，避免误吃其它 section 的同名键。
    local section = line:match("^%s*%[([^%]]+)%]%s*$")
    if section then
      in_settings = section == "settings"
    elseif in_settings then
      local key, value = line:match("^%s*([%w_-]+)%s*=%s*(.-)%s*$")
      if key == name then
        return trim(value)
      end
    end
  end
end

local function dashboard_url()
  local api_url = read_setting("api_url")
  if api_url == nil or api_url == "" then
    return "https://wakatime.com/dashboard"
  end

  -- 自建 WakaTime API 通常以 /api 结尾；浏览器入口需要回到站点根地址。
  return api_url:gsub("/+$", ""):gsub("/api/?$", "")
end

local function open_dashboard()
  vim.ui.open(dashboard_url())
end

return {
  "wakatime/vim-wakatime",
  event = "User ConfigUiReady",
  priority = 960,
  opts = {
    status_bar_enabled = false,
  },
  init = function()
    -- 官方仓库已带 Neovim Lua 实现；这里跳过 plugin/wakatime.vim 的自动入口，
    -- 由下面的 config 显式传入 opts，避免它把状态栏组件塞到 lualine_x。
    vim.g.loaded_wakatime = 1
  end,
  config = function(_, opts)
    require("wakatime").setup(opts)

    vim.api.nvim_create_user_command("WakaTimeDashboard", open_dashboard, {
      desc = "Open WakaTime dashboard in browser",
    })
  end,
}
