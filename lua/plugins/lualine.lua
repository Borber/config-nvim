local function min_cols(n)
  return function()
    return vim.o.columns > n
  end
end

local mode_labels = {
  NORMAL = "N",
  ["O-PENDING"] = "O",
  VISUAL = "V",
  ["V-LINE"] = "VL",
  ["V-BLOCK"] = "VB",
  SELECT = "S",
  ["S-LINE"] = "SL",
  ["S-BLOCK"] = "SB",
  INSERT = "I",
  REPLACE = "R",
  ["V-REPLACE"] = "VR",
  COMMAND = "C",
  EX = "EX",
  MORE = "M",
  CONFIRM = "CF",
  SHELL = "SH",
  TERMINAL = "T",
}

local function short_mode(mode)
  return mode_labels[mode] or mode:sub(1, 1)
end

local wakatime_status_module = "plugins.lualine.wakatime_status"

-- 状态栏渲染阶段只读已加载模块，避免首屏同步 require WakaTime。
local function loaded_wakatime_status()
  local wakatime = package.loaded[wakatime_status_module]
  if type(wakatime) ~= "table" then
    return nil
  end

  return wakatime
end

local function wakatime_component()
  local wakatime = loaded_wakatime_status()
  if wakatime == nil then
    return ""
  end

  return wakatime.component()
end

local function has_wakatime_today()
  local wakatime = loaded_wakatime_status()
  return wakatime ~= nil and wakatime.has_today()
end

local function setup_wakatime_refresh()
  local lifecycle = require("config.lifecycle")

  local function setup()
    -- 让出一轮调度，等 lualine 首屏完成后再启动 WakaTime 查询。
    vim.schedule(function()
      require(wakatime_status_module).setup_refresh()
    end)
  end

  lifecycle.once("ui_ready", function()
    setup()
  end, {
    group = vim.api.nvim_create_augroup("ConfigLualineWakaTimeRefresh", { clear = true }),
    desc = "Start lualine WakaTime refresh after UI startup",
  })
end

local function is_branch_probe_buffer(bufnr)
  local buffer_util = require("libs.buffer")
  local path_util = require("libs.path")

  if not buffer_util.is_normal_file(bufnr) then
    return false
  end

  -- 目录占位 buffer 不是 branch 探测的好上下文；等真实文件出现后再刷新。
  return not path_util.is_directory(vim.api.nvim_buf_get_name(bufnr))
end

-- lualine 的 branch 组件初始化时只看当前 buffer；启动页/目录占位 buffer 会让缓存先变空。
local function branch_probe_buffer(preferred_bufnr)
  if preferred_bufnr ~= nil and is_branch_probe_buffer(preferred_bufnr) then
    return preferred_bufnr
  end

  local current = vim.api.nvim_get_current_buf()
  if is_branch_probe_buffer(current) then
    return current
  end

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if is_branch_probe_buffer(bufnr) then
      return bufnr
    end
  end
end

local function refresh_branch_statusline(preferred_bufnr)
  local bufnr = branch_probe_buffer(preferred_bufnr)
  if bufnr == nil then
    return
  end

  local git_branch = require("lualine.components.branch.git_branch")
  -- 用真实文件 buffer 的上下文刷新 git_dir，否则首次打开仓库时要等 BufEnter 才能看到分支。
  vim.api.nvim_buf_call(bufnr, git_branch.find_git_dir)

  require("plugins.lualine.refresh").statusline(true)
end

local function setup_branch_refresh()
  local lifecycle = require("config.lifecycle")
  local group = vim.api.nvim_create_augroup("ConfigLualineBranchRefresh", { clear = true })

  -- ConfigFilePost 可能触发本次加载，也可能早于手动加载的 lualine；两边都兜住才能稳定刷新首次状态栏。
  lifecycle.on("file_post", function(event)
    local bufnr = event.data and event.data.buf or event.buf
    vim.schedule(function()
      refresh_branch_statusline(bufnr)
    end)
  end, {
    group = group,
    schedule = false,
    desc = "Refresh lualine branch after first real file",
  })
end

return {
  "nvim-lualine/lualine.nvim",
  lazy = false,
  priority = 950,
  opts = function()
    local ic = require("libs.icons")
    local theme = require("plugins.lualine.theme")

    return {
      options = {
        theme = theme.statusline(),
        globalstatus = true,
        always_divide_middle = false,
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
        disabled_filetypes = { statusline = { "ministarter" } },
      },
      sections = {
        lualine_a = {
          {
            "mode",
            fmt = short_mode,
          },
        },
        lualine_b = {
          {
            "branch",
            icon = ic.git.branch,
            color = { gui = "bold" },
            cond = min_cols(100),
          },
        },
        lualine_c = {
          {
            -- WakaTime 单独占第三段，用自己的背景和 diagnostics 区分。
            -- 组件函数只展示缓存文本；真正的外部查询由 UI ready 后的刷新逻辑触发。
            wakatime_component,
            cond = has_wakatime_today,
            color = theme.wakatime_color,
          },
          {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            symbols = { error = ic.lsp.error, warn = ic.lsp.warn, info = ic.lsp.info },
            cond = min_cols(120),
          },
        },
        lualine_x = {},
        lualine_y = { { "filetype", cond = min_cols(80) } },
        lualine_z = {
          { ic.os_icon },
        },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
      -- 顶部只展示 buffer 列表；原生 tab/tabby 不再承担文件切换职责。
      tabline = {
        lualine_a = {
          {
            function()
              return ic.ui.vim
            end,
            padding = { left = 1, right = 1 },
          },
        },
        lualine_b = {
          {
            "buffers",
            mode = 0,
            show_modified_status = true,
            max_length = function()
              return vim.o.columns
            end,
            symbols = {
              modified = " " .. ic.basic.modified,
              alternate_file = "",
              directory = ic.basic.dir,
            },
            buffers_color = {
              active = theme.buffer_active_color(),
              inactive = theme.buffer_inactive_color(),
            },
          },
        },
        lualine_c = {},
        lualine_x = {},
        lualine_y = {},
        lualine_z = {},
      },
      extensions = { "lazy", "quickfix", "man" },
    }
  end,
  config = function(_, opts)
    require("config.lifecycle").setup()
    require("lualine").setup(opts)
    setup_branch_refresh()
    setup_wakatime_refresh()
  end,
}
