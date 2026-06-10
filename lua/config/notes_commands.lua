local M = {}
local api = vim.api

local function note_action(method)
  return function()
    require("config.notes")[method]()
  end
end

function M.setup()
  api.nvim_create_user_command("Notes", note_action("toggle"), {
    desc = "Toggle global Markdown notes drawer",
    force = true,
  })

  api.nvim_create_user_command("NotesInbox", note_action("toggle_inbox"), {
    desc = "Toggle global Markdown inbox",
    force = true,
  })

  api.nvim_create_user_command("NotesJournal", note_action("toggle_journal"), {
    desc = "Toggle global Markdown journal",
    force = true,
  })

  vim.keymap.set("n", "<leader>nn", note_action("toggle"), { silent = true, desc = "Toggle notes" })
  vim.keymap.set("n", "<leader>ni", note_action("toggle_inbox"), { silent = true, desc = "Toggle notes inbox" })
  vim.keymap.set("n", "<leader>nj", note_action("toggle_journal"), { silent = true, desc = "Toggle notes journal" })
end

return M
