local function apply_gitsigns_highlights()
  local color = require("util.color")
  local p = require("util.palette").everforest
  local highlights = {
    GitSignsCurrentLineBlame = { fg = p.muted, italic = true },
    GitSignsAddPreview = { fg = p.green, bg = color.blend_hex(p.green, p.base, 0.12) },
    GitSignsDeletePreview = { fg = p.red, bg = color.blend_hex(p.red, p.base, 0.12) },
    GitSignsAddInline = { fg = p.green, bg = color.blend_hex(p.green, p.base, 0.28), bold = true },
    GitSignsDeleteInline = { fg = p.red, bg = color.blend_hex(p.red, p.base, 0.28), bold = true },
    GitSignsChangeInline = { fg = p.blue, bg = color.blend_hex(p.blue, p.base, 0.24), bold = true },
    GitSignsNoEOLPreview = { fg = p.gold, bg = color.blend_hex(p.gold, p.base, 0.16) },
  }

  for group, highlight in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, highlight)
  end

  require("util.float").apply_highlights()
end

local function preview_width()
  return math.min(96, math.max(1, vim.o.columns - 8))
end

local lifecycle = require("config.lifecycle")

return {
  "lewis6991/gitsigns.nvim",
  -- 首个真实文件出现后再加载，starter 首屏不需要 git sign；blame 仍保持手动开启。
  event = lifecycle.lazy_events.ui_ready,
  opts = function()
    local float = require("util.float")
    local icons = require("libs.icons").git

    return {
      signs = {
        add = { text = icons.sign },
        change = { text = icons.sign },
        delete = { text = icons.delete },
        topdelete = { text = icons.delete },
        changedelete = { text = icons.sign },
        untracked = { text = icons.sign },
      },
      signcolumn = true,
      current_line_blame = false,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 500,
        ignore_whitespace = false,
        virt_text_priority = 120,
        use_focus = true,
      },
      current_line_blame_formatter = "  " .. icons.blame .. " <summary>, " .. icons.author .. " <author> (<author_time:%R>)",
      current_line_blame_formatter_nc = "  " .. icons.blame .. " Not committed yet",
      preview_config = {
        style = "minimal",
        relative = "cursor",
        row = 1,
        col = 2,
        width = preview_width(),
        border = float.borderchars("GitSignsPreviewBorder"),
        title = float.title(icons.title .. " Gitsigns", "GitSignsPreviewTitle"),
        title_pos = "center",
        zindex = 50,
      },
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
        end
        local range = function()
          return { vim.fn.line("."), vim.fn.line("v") }
        end

        map("n", "]h", function()
          gs.nav_hunk("next")
        end, "Next hunk")
        map("n", "[h", function()
          gs.nav_hunk("prev")
        end, "Prev hunk")
        map("n", "<leader>gh", gs.stage_hunk, "Stage hunk")
        map("x", "<leader>gh", function()
          gs.stage_hunk(range())
        end, "Stage hunk")
        map("n", "<leader>gH", gs.reset_hunk, "Reset hunk")
        map("x", "<leader>gH", function()
          gs.reset_hunk(range())
        end, "Reset hunk")
        map("n", "<leader>gp", gs.preview_hunk, "Preview hunk")
        map("n", "<leader>gb", function()
          gs.blame_line({ full = true })
        end, "Blame line")
        map("n", "<leader>gB", gs.toggle_current_line_blame, "Toggle blame")
      end,
    }
  end,
  config = function(_, opts)
    local group = vim.api.nvim_create_augroup("UserGitsignsHighlights", { clear = true })
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = group,
      callback = apply_gitsigns_highlights,
    })

    apply_gitsigns_highlights()
    require("gitsigns").setup(opts)
  end,
}
