local M = {}

function M.setup()
  local starter = require("mini.starter")
  local visits = require("plugins.mini.visits")

  starter.setup({
    header = "",
    footer = "",
    items = {
      {
        name = "Find file",
        action = function()
          require("telescope.builtin").find_files()
        end,
        section = "Actions",
      },
      {
        name = "New file",
        action = "ene | startinsert",
        section = "Actions",
      },
      {
        name = "Open folder",
        action = function()
          local dir = vim.fn.input("Open folder: ", vim.fn.getcwd(), "dir")
          if dir == "" or vim.fn.isdirectory(dir) == 0 then
            return
          end

          visits.open_path(dir)
        end,
        section = "Actions",
      },
      {
        name = "New tab",
        action = "tabnew",
        section = "Actions",
      },
      {
        name = "Config",
        action = function()
          vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.stdpath("config")))
        end,
        section = "Actions",
      },
      {
        name = "Quit",
        action = "qa",
        section = "Actions",
      },
      visits.recent_paths_section(5),
    },
    content_hooks = {
      starter.gen_hook.aligning("center", "center"),
    },
    silent = true,
  })
end

return M
