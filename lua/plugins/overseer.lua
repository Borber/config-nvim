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
    "OverseerRun",
    "OverseerShell",
    "OverseerTaskAction",
  },
  keys = {
    { "<leader>jr", "<Cmd>OverseerRun<CR>", desc = "Run task" },
    { "<leader>jo", "<Cmd>OverseerToggle<CR>", desc = "Toggle tasks" },
    { "<leader>jc", "<Cmd>OverseerClose<CR>", desc = "Close tasks" },
    { "<leader>ja", "<Cmd>OverseerTaskAction<CR>", desc = "Task action" },
    { "<leader>jf", open_failed_output, desc = "Failed task output" },
    { "<leader>js", "<Cmd>OverseerShell<CR>", desc = "Shell task" },
    { "<leader>jC", clear_task_cache, desc = "Clear task cache" },
  },
  ---@module "overseer"
  ---@type overseer.SetupOpts
  opts = function()
    local float = require("util.float")

    return {
      task_list = {
        direction = "bottom",
        min_height = 8,
        max_height = { 20, 0.25 },
      },
      form = {
        border = float.border,
      },
      task_win = {
        border = float.border,
      },
    }
  end,
  config = function(_, opts)
    require("patches.overseer_select").apply()
    local overseer = require("overseer")
    overseer.setup(opts)
    setup_failure_output(overseer)
  end,
}
