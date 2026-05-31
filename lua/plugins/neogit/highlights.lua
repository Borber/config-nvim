local M = {}
local color = require("util.color")

function M.apply()
  local p = require("util.palette").everforest
  local bg = "NONE"
  local highlights = {
    NeogitNormal = { fg = p.text, bg = bg },
    NeogitNormalFloat = { fg = p.text, bg = bg },
    NeogitFloatBorder = { fg = p.overlay, bg = bg },
    NeogitWinSeparator = { fg = p.overlay, bg = bg },
    NeogitSignColumn = { fg = p.blue, bg = bg },
    NeogitFoldColumn = { fg = p.muted, bg = bg },
    NeogitCursorLine = { bg = p.surface },
    NeogitActiveItem = { fg = p.text, bg = p.overlay, bold = true },

    NeogitStatusHEAD = { fg = p.blue, bold = true },
    NeogitBranch = { fg = p.green, bold = true },
    NeogitBranchHead = { fg = p.green, bg = p.surface, bold = true },
    NeogitRemote = { fg = p.aqua, bold = true },
    NeogitObjectId = { fg = p.muted },
    NeogitTagName = { fg = p.gold, bold = true },
    NeogitTagDistance = { fg = p.aqua },
    NeogitStash = { fg = p.subtle, italic = true },

    NeogitChangeModified = { fg = p.blue, bold = true },
    NeogitChangeAdded = { fg = p.green, bold = true },
    NeogitChangeNewFile = { fg = p.aqua, bold = true },
    NeogitChangeDeleted = { fg = p.red, bold = true },
    NeogitChangeRenamed = { fg = p.gold, bold = true },
    NeogitChangeUpdated = { fg = p.orange, bold = true },
    NeogitChangeCopied = { fg = p.aqua, bold = true },
    NeogitChangeUnmerged = { fg = p.red, bold = true },
    NeogitFilePath = { fg = p.green },

    NeogitDiffHeader = { fg = p.green, bg = p.surface, bold = true },
    NeogitDiffHeaderHighlight = { fg = p.green, bg = p.overlay, bold = true },
    NeogitHunkHeader = { fg = p.text, bg = p.surface, bold = true },
    NeogitHunkHeaderHighlight = { fg = p.blue, bg = p.overlay, bold = true },
    NeogitHunkHeaderCursor = { fg = p.blue, bg = p.overlay, bold = true },
    NeogitDiffContext = { bg = bg },
    NeogitDiffContextHighlight = { bg = p.overlay },
    NeogitDiffAdd = { fg = p.green },
    NeogitDiffAddHighlight = { fg = p.green, bg = color.blend_hex(p.green, p.base, 0.16) },
    NeogitDiffAddCursor = { fg = p.green, bg = p.surface },
    NeogitDiffDelete = { fg = p.red },
    NeogitDiffDeleteHighlight = { fg = p.red, bg = color.blend_hex(p.red, p.base, 0.16) },
    NeogitDiffDeleteCursor = { fg = p.red, bg = p.surface },
    NeogitDiffAddInline = { fg = p.green, bold = true, underline = true },
    NeogitDiffDeleteInline = { fg = p.red, bold = true, underline = true },
    NeogitDiffAdditions = { fg = p.green, bold = true },
    NeogitDiffDeletions = { fg = p.red, bold = true },
  }

  for group, highlight in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, highlight)
  end
end

return M
