local icons = {
  -- 统一用 codepoint 生成 glyph，避免源文件里直接混入不稳定的 Nerd Font 字符。
  author = vim.fn.nr2char(0xf007),
  blame = vim.fn.nr2char(0xe729),
  delete = vim.fn.nr2char(0x2578),
  sign = vim.fn.nr2char(0x2503),
  title = vim.fn.nr2char(0xf2a2),
}

local function apply_gitsigns_highlights()
  local highlights = {
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

  require("util.float").apply_highlights()
end

local function preview_width()
  return math.min(96, math.max(1, vim.o.columns - 8))
end

return {
  "lewis6991/gitsigns.nvim",
  -- 等 UI 和真实文件都准备好后再加载，避免启动页/目录占位 buffer 触发 git 探测。
  event = "User ConfigFilePost",
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
      add = { text = icons.sign },
      change = { text = icons.sign },
      delete = { text = icons.delete },
      topdelete = { text = icons.delete },
      changedelete = { text = icons.sign },
      untracked = { text = icons.sign },
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
    current_line_blame_formatter = "  " .. icons.blame .. " <summary>, " .. icons.author .. " <author> (<author_time:%R>)",
    current_line_blame_formatter_nc = "  " .. icons.blame .. " Not committed yet",
    preview_config = {
      style = "minimal",
      relative = "cursor",
      row = 1,
      col = 2,
      width = preview_width(),
      border = require("util.float").borderchars("GitSignsPreviewBorder"),
      title = require("util.float").title(icons.title .. " Gitsigns", "GitSignsPreviewTitle"),
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
  },
}
