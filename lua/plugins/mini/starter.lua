local M = {}

function M.setup()
  local starter = require("mini.starter")

  starter.setup({
    header = "",
    footer = "",
    items = {
      starter.sections.recent_files(5, false, true),
      {
        name = "Find file",
        action = function()
          require("mini.pick").builtin.files()
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

          vim.cmd("edit " .. vim.fn.fnameescape(dir))
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
    },
    content_hooks = {
      starter.gen_hook.aligning("center", "center"),
    },
    silent = true,
  })
end

return M
