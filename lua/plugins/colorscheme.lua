return {
  "rose-pine/neovim",
  name = "rose-pine",
  lazy = false,
  priority = 1000,
  config = function()
    local color = require("util.color")
    local float = require("util.float")
    local everforest = require("util.palette").everforest

    local function set_hl(group, opts)
      vim.api.nvim_set_hl(0, group, opts)
    end

    local function link(group, target)
      set_hl(group, { link = target })
    end

    local function apply_editor_highlights()
      local p = everforest
      local cursor_line = color.blend_hex(p.surface, p.base, 0.72)
      local visual = color.blend_hex(p.blue, p.base, 0.28)
      local search = color.blend_hex(p.gold, p.base, 0.34)

      set_hl("Normal", { fg = p.text, bg = "NONE" })
      set_hl("NormalNC", { fg = p.text, bg = "NONE" })
      set_hl("EndOfBuffer", { fg = p.base, bg = "NONE" })
      set_hl("SignColumn", { fg = p.muted, bg = "NONE" })
      set_hl("FoldColumn", { fg = p.muted, bg = "NONE" })
      set_hl("LineNr", { fg = p.muted, bg = "NONE" })
      set_hl("CursorLine", { bg = cursor_line })
      set_hl("CursorLineNr", { fg = p.green, bg = cursor_line, bold = true })
      set_hl("Visual", { bg = visual })
      set_hl("Search", { fg = p.base, bg = search })
      set_hl("IncSearch", { fg = p.base, bg = p.gold, bold = true })
      set_hl("CurSearch", { fg = p.base, bg = p.gold, bold = true })
      set_hl("MatchParen", { fg = p.gold, bg = color.blend_hex(p.gold, p.base, 0.18), bold = true })
      set_hl("ColorColumn", { bg = p.surface })

      set_hl("Comment", { fg = p.muted, italic = true })
      set_hl("Constant", { fg = p.orange })
      set_hl("String", { fg = p.gold })
      set_hl("Character", { fg = p.gold })
      set_hl("Number", { fg = p.orange })
      set_hl("Boolean", { fg = p.orange })
      set_hl("Float", { fg = p.orange })
      set_hl("Identifier", { fg = p.text })
      set_hl("Function", { fg = p.green })
      set_hl("Statement", { fg = p.orange })
      set_hl("Conditional", { fg = p.orange })
      set_hl("Repeat", { fg = p.orange })
      set_hl("Label", { fg = p.gold })
      set_hl("Operator", { fg = p.blue })
      set_hl("Keyword", { fg = p.orange, italic = true })
      set_hl("Exception", { fg = p.red })
      set_hl("PreProc", { fg = p.aqua })
      set_hl("Include", { fg = p.aqua })
      set_hl("Define", { fg = p.aqua })
      set_hl("Macro", { fg = p.aqua })
      set_hl("Type", { fg = p.aqua })
      set_hl("StorageClass", { fg = p.aqua })
      set_hl("Structure", { fg = p.aqua })
      set_hl("Typedef", { fg = p.aqua })
      set_hl("Special", { fg = p.blue })
      set_hl("SpecialChar", { fg = p.blue })
      set_hl("Tag", { fg = p.green })
      set_hl("Delimiter", { fg = p.subtle })
      set_hl("Todo", { fg = p.gold, bold = true })
      set_hl("Error", { fg = p.red })
      set_hl("ErrorMsg", { fg = p.red, bold = true })
      set_hl("WarningMsg", { fg = p.gold, bold = true })
      set_hl("Directory", { fg = p.green, bold = true })
    end

    local function apply_treesitter_highlights()
      local p = everforest

      link("@comment", "Comment")
      set_hl("@variable", { fg = p.text })
      set_hl("@variable.parameter", { fg = p.text, italic = true })
      set_hl("@variable.member", { fg = p.aqua })
      set_hl("@property", { fg = p.aqua })
      set_hl("@field", { fg = p.aqua })
      set_hl("@function", { fg = p.green })
      set_hl("@function.call", { fg = p.green })
      set_hl("@function.method", { fg = p.green })
      set_hl("@function.method.call", { fg = p.green })
      set_hl("@constructor", { fg = p.aqua })
      set_hl("@keyword", { fg = p.orange, italic = true })
      set_hl("@keyword.function", { fg = p.orange, italic = true })
      set_hl("@keyword.return", { fg = p.orange, italic = true })
      set_hl("@keyword.conditional", { fg = p.orange, italic = true })
      set_hl("@keyword.repeat", { fg = p.orange, italic = true })
      set_hl("@keyword.operator", { fg = p.blue })
      set_hl("@operator", { fg = p.blue })
      set_hl("@string", { fg = p.gold })
      set_hl("@string.escape", { fg = p.blue })
      set_hl("@number", { fg = p.orange })
      set_hl("@boolean", { fg = p.orange })
      set_hl("@constant", { fg = p.orange })
      set_hl("@constant.builtin", { fg = p.orange, italic = true })
      set_hl("@type", { fg = p.aqua })
      set_hl("@type.builtin", { fg = p.aqua, italic = true })
      set_hl("@module", { fg = p.aqua })
      set_hl("@namespace", { fg = p.aqua })
      set_hl("@label", { fg = p.gold })
      set_hl("@punctuation", { fg = p.subtle })
      set_hl("@punctuation.bracket", { fg = p.subtle })
      set_hl("@punctuation.delimiter", { fg = p.subtle })
      set_hl("@tag", { fg = p.green })
      set_hl("@tag.attribute", { fg = p.aqua })
      set_hl("@tag.delimiter", { fg = p.subtle })
      set_hl("@markup.heading", { fg = p.green, bold = true })
      set_hl("@markup.link", { fg = p.blue, underline = true })
      set_hl("@markup.raw", { fg = p.gold })
      set_hl("@diff.plus", { fg = p.green })
      set_hl("@diff.minus", { fg = p.red })
      set_hl("@diff.delta", { fg = p.gold })

      link("@lsp.type.comment", "Comment")
      set_hl("@lsp.type.variable", { fg = p.text })
      set_hl("@lsp.type.parameter", { fg = p.text, italic = true })
      set_hl("@lsp.type.property", { fg = p.aqua })
      set_hl("@lsp.type.function", { fg = p.green })
      set_hl("@lsp.type.method", { fg = p.green })
      set_hl("@lsp.type.keyword", { fg = p.orange, italic = true })
      set_hl("@lsp.type.operator", { fg = p.blue })
      set_hl("@lsp.type.string", { fg = p.gold })
      set_hl("@lsp.type.number", { fg = p.orange })
      set_hl("@lsp.type.boolean", { fg = p.orange })
      set_hl("@lsp.type.type", { fg = p.aqua })
      set_hl("@lsp.type.namespace", { fg = p.aqua })
    end

    local function apply_highlights()
      apply_editor_highlights()
      float.apply_highlights()
      apply_treesitter_highlights()
    end

    require("rose-pine").setup({
      variant = "main",
      dark_variant = "main",
      extend_background_behind_borders = true,
      styles = {
        transparency = true,
      },
    })

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ConfigThemeAppearance", { clear = true }),
      callback = apply_highlights,
    })

    vim.cmd("colorscheme rose-pine-main")
  end,
}
