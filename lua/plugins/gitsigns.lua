local function apply_gitsigns_highlights()
  local bg = require("util.float").normal_bg() or "#faf4ed"
  local highlights = {
    GitSignsPreviewBorder = { fg = "#cecacd", bg = bg },
    GitSignsPreviewTitle = { fg = "#907aa9", bg = bg, bold = true },
    GitSignsCurrentLineBlame = { fg = "#9893a5", italic = true },
    GitSignsAddPreview = { fg = "#286983", bg = "#f1f7f3" },
    GitSignsDeletePreview = { fg = "#b4637a", bg = "#faecef" },
    GitSignsAddInline = { fg = "#286983", bg = "#dceee3", bold = true },
    GitSignsDeleteInline = { fg = "#b4637a", bg = "#f2d8dd", bold = true },
    GitSignsChangeInline = { fg = "#907aa9", bg = "#ece6f2", bold = true },
    GitSignsNoEOLPreview = { fg = "#ea9d34", bg = "#fff4dc" },
  }

  for group, highlight in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, highlight)
  end
end

local function preview_width()
  return math.min(96, math.max(1, vim.o.columns - 8))
end
return {
  "lewis6991/gitsigns.nvim",
  event = { "BufReadPost", "BufNewFile" },
  init = function()
    local group = vim.api.nvim_create_augroup("UserGitsignsHighlights", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = apply_gitsigns_highlights,
    })

    apply_gitsigns_highlights()
  end,
  opts = {
    signs = {
      add          = { text = "┃" },
      change       = { text = "┃" },
      delete       = { text = "╸"},
      topdelete    = { text = "╸" },
      changedelete = { text = "┃" },
      untracked    = { text = "┃" },
    },
    signcolumn = false,
    _statuscolumn = true,
    current_line_blame = true,
    current_line_blame_opts = {
      virt_text = true,
      virt_text_pos = "eol",
      delay = 500,
      ignore_whitespace = false,
      virt_text_priority = 120,
      use_focus = true,
    },
    current_line_blame_formatter = "   <summary>,  <author> (<author_time:%R>)",
    current_line_blame_formatter_nc = "   Not committed yet",
    preview_config = {
      style = "minimal",
      relative = "cursor",
      row = 1,
      col = 2,
      width = preview_width(),
      border = require("util.float").borderchars("GitSignsPreviewBorder"),
      title = { { " 󰊢 Gitsigns ", "GitSignsPreviewTitle" } },
      title_pos = "center",
      zindex = 50,
    },
    on_attach = function(bufnr)
      local gs = require("gitsigns")
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
      end

      map("n", "]h", function() gs.nav_hunk("next") end, "Next hunk")
      map("n", "[h", function() gs.nav_hunk("prev") end, "Prev hunk")
      map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
      map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
      map("n", "<leader>hp", gs.preview_hunk, "Preview hunk")
      map("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "Blame line")
      map("n", "<leader>hB", gs.toggle_current_line_blame, "Toggle blame")
    end,
  },
}
