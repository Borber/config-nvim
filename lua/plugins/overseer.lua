local buffer_util = require("libs.buffer")
local telescope_picker = require("util.telescope_picker")

-- Overseer 模板搜索以当前文件目录为主；当前不是普通文件时退回 cwd。
-- 这样从特殊 buffer（例如 Neogit/terminal）触发任务时不会拿到无意义路径。
local function search_params()
  local dir = vim.fn.getcwd()
  if buffer_util.is_normal_file(0) then
    local bufname = vim.api.nvim_buf_get_name(0)
    dir = vim.fn.fnamemodify(bufname, ":p:h")
  end

  return {
    dir = dir,
    filetype = vim.bo.filetype,
  }
end

local function template_label(tmpl)
  if tmpl.desc and tmpl.desc ~= "" then
    return string.format("%s  %s", tmpl.name, tmpl.desc)
  end

  return tmpl.name
end

local function setup_overseer_select()
  vim.ui._config_overseer_original_select = vim.ui._config_overseer_original_select or vim.ui.select
  local original_select = vim.ui._config_overseer_original_select

  -- Overseer 的模板和 action 都走 vim.ui.select；只拦截 kind=overseer*，
  -- 其它插件仍使用原本的 vim.ui.select，避免全局 UI 行为被这个配置意外改写。
  rawset(vim.ui, "select", function(items, opts, on_choice)
    if opts and type(opts.kind) == "string" and vim.startswith(opts.kind, "overseer") then
      telescope_picker.select(items, opts, on_choice)
      return
    end

    original_select(items, opts, on_choice)
  end)
end

local function setup_failure_output(overseer)
  -- 失败时自动打开输出，弥补任务列表默认收起时不容易看到错误详情的问题。
  overseer.add_template_hook({}, function(task_defn, util)
    util.add_component(task_defn, {
      "open_output",
      -- open_output 默认会在启动时展开输出；这里只保留失败后的自动展开。
      on_start = "never",
      on_complete = "failure",
      direction = "dock",
      focus = true,
    })
  end)
end

local function run_task()
  local overseer = require("overseer")
  local template = require("overseer.template")
  local params = search_params()

  template.list(params, function(templates)
    local task_templates = vim
      .iter(templates)
      :filter(function(tmpl)
        return not tmpl.hide
      end)
      :totable()

    table.sort(task_templates, function(a, b)
      return a.name < b.name
    end)

    if #task_templates == 0 then
      vim.notify("No tasks found", vim.log.levels.WARN)
      return
    end

    telescope_picker.select(task_templates, {
      prompt = "Task",
      format_item = template_label,
    }, function(tmpl)
      if tmpl then
        overseer.run_task({
          name = tmpl.name,
          search_params = params,
        })
      end
    end)
  end)
end

local function open_failed_output()
  local constants = require("overseer.constants")
  local task_list = require("overseer.task_list")
  local tasks = task_list.list_tasks({
    status = constants.STATUS.FAILURE,
    include_ephemeral = true,
    sort = task_list.sort_finished_recently,
  })

  local task = tasks[1]
  if task == nil then
    vim.notify("No failed tasks", vim.log.levels.INFO)
    return
  end

  task:open_output("float")
end

local function clear_task_cache()
  require("overseer").clear_task_cache()
  vim.notify("Overseer task cache cleared", vim.log.levels.INFO)
end

return {
  "stevearc/overseer.nvim",
  cmd = {
    "OverseerOpen",
    "OverseerClose",
    "OverseerToggle",
    "OverseerShell",
    "OverseerTaskAction",
  },
  keys = {
    { "<leader>jr", run_task, desc = "Run task" },
    { "<leader>jo", "<Cmd>OverseerToggle<CR>", desc = "Toggle tasks" },
    { "<leader>jc", "<Cmd>OverseerClose<CR>", desc = "Close tasks" },
    { "<leader>ja", "<Cmd>OverseerTaskAction<CR>", desc = "Task action" },
    { "<leader>jf", open_failed_output, desc = "Failed task output" },
    { "<leader>js", "<Cmd>OverseerShell<CR>", desc = "Shell task" },
    { "<leader>jC", clear_task_cache, desc = "Clear task cache" },
  },
  ---@module "overseer"
  ---@type overseer.SetupOpts
  opts = {
    task_list = {
      direction = "bottom",
      min_height = 8,
      max_height = { 20, 0.25 },
    },
    form = {
      border = require("util.float").border,
    },
    task_win = {
      border = require("util.float").border,
    },
  },
  config = function(_, opts)
    setup_overseer_select()
    local overseer = require("overseer")
    overseer.setup(opts)
    setup_failure_output(overseer)
  end,
}
