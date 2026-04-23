local M = {}

local function toggle_files()
  local minifiles = require("mini.files")
  local path = vim.api.nvim_buf_get_name(0)

  if path == "" then
    path = vim.fn.getcwd()
  end

  if not minifiles.close() then
    minifiles.open(path, true)
  end
end

function M.setup()
  require("mini.files").setup({
    options = {
      use_as_default_explorer = true,
    },
  })

  vim.api.nvim_create_autocmd("User", {
    pattern = "MiniFilesBufferCreate",
    callback = function(args)
      local visits = require("plugins.mini.visits")
      local buf_id = args.data.buf_id
      local path = vim.api.nvim_buf_get_name(buf_id):match("^minifiles://%d+/(.+)$")

      visits.register_directory(path)

      vim.keymap.set("n", "<Esc>", function()
        require("mini.files").close()
      end, {
        buffer = buf_id,
        desc = "Close explorer",
        silent = true,
      })
    end,
  })

  vim.keymap.set("n", "<leader>e", toggle_files, {
    desc = "Explorer",
    silent = true,
  })
  vim.keymap.set("n", "<localleader>e", toggle_files, {
    desc = "Explorer",
    silent = true,
  })
end

return M
