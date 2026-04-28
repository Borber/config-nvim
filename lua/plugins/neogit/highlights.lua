local M = {}

local rose_pine_dawn = {
  base = "#faf4ed",
  surface = "#fffaf3",
  muted = "#9893a5",
  subtle = "#797593",
  text = "#575279",
  love = "#b4637a",
  gold = "#ea9d34",
  rose = "#d7827e",
  pine = "#286983",
  foam = "#56949f",
  iris = "#907aa9",
  highlight_low = "#f4ede8",
  highlight_med = "#dfdad9",
  highlight_high = "#cecacd",
}

function M.apply()
  local p = rose_pine_dawn
  local highlights = {
    NeogitNormal = { fg = p.text, bg = p.base },
    NeogitNormalFloat = { fg = p.text, bg = p.surface },
    NeogitFloatBorder = { fg = p.highlight_high, bg = p.surface },
    NeogitWinSeparator = { fg = p.highlight_high, bg = p.base },
    NeogitSignColumn = { fg = p.iris, bg = p.base },
    NeogitFoldColumn = { fg = p.muted, bg = p.base },
    NeogitCursorLine = { bg = p.highlight_low },
    NeogitActiveItem = { fg = p.text, bg = p.highlight_med, bold = true },

    NeogitStatusHEAD = { fg = p.iris, bold = true },
    NeogitBranch = { fg = p.pine, bold = true },
    NeogitBranchHead = { fg = p.pine, bg = p.highlight_low, bold = true },
    NeogitRemote = { fg = p.foam, bold = true },
    NeogitObjectId = { fg = p.muted },
    NeogitTagName = { fg = p.gold, bold = true },
    NeogitTagDistance = { fg = p.foam },
    NeogitStash = { fg = p.subtle, italic = true },

    NeogitChangeModified = { fg = p.iris, bold = true },
    NeogitChangeAdded = { fg = p.pine, bold = true },
    NeogitChangeNewFile = { fg = p.foam, bold = true },
    NeogitChangeDeleted = { fg = p.love, bold = true },
    NeogitChangeRenamed = { fg = p.gold, bold = true },
    NeogitChangeUpdated = { fg = p.rose, bold = true },
    NeogitChangeCopied = { fg = p.foam, bold = true },
    NeogitChangeUnmerged = { fg = p.love, bold = true },
    NeogitFilePath = { fg = p.pine },

    NeogitDiffHeader = { fg = p.pine, bg = p.highlight_low, bold = true },
    NeogitDiffHeaderHighlight = { fg = p.pine, bg = p.highlight_med, bold = true },
    NeogitHunkHeader = { fg = p.text, bg = p.highlight_low, bold = true },
    NeogitHunkHeaderHighlight = { fg = p.iris, bg = p.highlight_med, bold = true },
    NeogitHunkHeaderCursor = { fg = p.iris, bg = p.highlight_med, bold = true },
    NeogitDiffContext = { bg = p.highlight_low },
    NeogitDiffContextHighlight = { bg = p.highlight_med },
    NeogitDiffAdd = { fg = p.pine },
    NeogitDiffAddHighlight = { fg = p.pine, bg = "#edf5ef" },
    NeogitDiffAddCursor = { fg = p.pine, bg = p.highlight_low },
    NeogitDiffDelete = { fg = p.love },
    NeogitDiffDeleteHighlight = { fg = p.love, bg = "#f8eaec" },
    NeogitDiffDeleteCursor = { fg = p.love, bg = p.highlight_low },
    NeogitDiffAddInline = { fg = p.pine, bold = true, underline = true },
    NeogitDiffDeleteInline = { fg = p.love, bold = true, underline = true },
    NeogitDiffAdditions = { fg = p.pine, bold = true },
    NeogitDiffDeletions = { fg = p.love, bold = true },
  }

  for group, highlight in pairs(highlights) do
    vim.api.nvim_set_hl(0, group, highlight)
  end
end

return M
