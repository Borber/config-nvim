local M = {}
local configured = false

local function current_recent_path()
  local content = require("mini.starter").get_content()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local content_line = content[cursor_line]

  if content_line == nil then
    return nil
  end

  for _, unit in ipairs(content_line) do
    if unit.type == "item" and unit.item ~= nil and unit.item.section == "Recent paths" then
      return unit.item.recent_path
    end
  end

  return nil
end

local function delete_current_recent_path()
  local recent_path = current_recent_path()
  if recent_path == nil then
    return
  end

  local visits = require("plugins.mini.visits")
  if visits.remove_recent_path(recent_path) then
    require("mini.starter").refresh()
  end
end

local function attach_starter_mappings(buf_id)
  vim.keymap.set("n", "<BS>", delete_current_recent_path, {
    buffer = buf_id,
    desc = "Delete recent path",
    silent = true,
  })
end

local function ensure_setup(autoopen)
  if configured then
    return
  end

  configured = true

  local starter = require("mini.starter")
  local visits = require("plugins.mini.visits")

  visits.setup()

  starter.setup({
    autoopen = autoopen == true,
    header = "",
    footer = "",
    items = {
      visits.recent_paths_section(5),
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

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("ConfigMiniStarterMappings", { clear = true }),
    pattern = "MiniStarterOpened",
    callback = function(args)
      attach_starter_mappings(args.buf ~= 0 and args.buf or vim.api.nvim_get_current_buf())
    end,
  })
end

function M.setup(opts)
  opts = opts or {}
  ensure_setup(opts.autoopen)
end

function M.open()
  ensure_setup(false)
  require("mini.starter").open()
end

return M
