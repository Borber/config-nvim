local function search_params()
  local dir = vim.fn.getcwd()
  if vim.bo.buftype == "" then
    local bufname = vim.api.nvim_buf_get_name(0)
    if bufname ~= "" then
      dir = vim.fn.fnamemodify(bufname, ":p:h")
    end
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

local function telescope_select(items, opts, on_choice)
  local has_telescope, pickers = pcall(require, "telescope.pickers")
  if not has_telescope then
    local original_select = vim.ui._config_overseer_original_select or vim.ui.select
    original_select(items, opts, on_choice)
    return
  end

  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local themes = require("telescope.themes")
  local format_item = opts and opts.format_item or tostring
  local entries = vim
    .iter(items)
    :enumerate()
    :map(function(index, item)
      return {
        index = index,
        value = item,
        display = format_item(item),
      }
    end)
    :totable()

  pickers.new(themes.get_dropdown({
    prompt_title = (opts and opts.prompt) or "Select",
    previewer = false,
    layout_config = {
      width = 0.65,
      height = 0.5,
    },
  }), {
    finder = finders.new_table({
      results = entries,
      entry_maker = function(entry)
        return {
          value = entry.value,
          index = entry.index,
          display = entry.display,
          ordinal = entry.display,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local function cancel()
        actions.close(prompt_bufnr)
        on_choice(nil)
      end

      actions.select_default:replace(function()
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        if entry then
          on_choice(entry.value, entry.index)
        else
          on_choice(nil)
        end
      end)
      map({ "i", "n" }, "<Esc>", cancel)
      map({ "i", "n" }, "<C-c>", cancel)
      map("n", "q", cancel)
      return true
    end,
  }):find()
end

local function setup_overseer_select()
  vim.ui._config_overseer_original_select = vim.ui._config_overseer_original_select or vim.ui.select
  local original_select = vim.ui._config_overseer_original_select

  -- Overseer uses vim.ui.select for task templates and actions; route only those through Telescope.
  vim.ui.select = function(items, opts, on_choice)
    if opts and type(opts.kind) == "string" and vim.startswith(opts.kind, "overseer") then
      telescope_select(items, opts, on_choice)
      return
    end

    original_select(items, opts, on_choice)
  end
end

local function setup_failure_output(overseer)
  overseer.add_template_hook({}, function(task_defn, util)
    util.add_component(task_defn, {
      "open_output",
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

    telescope_select(task_templates, {
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
      border = "rounded",
    },
    task_win = {
      border = "rounded",
    },
  },
  config = function(_, opts)
    setup_overseer_select()
    local overseer = require("overseer")
    overseer.setup(opts)
    setup_failure_output(overseer)
  end,
}
