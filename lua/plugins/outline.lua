local symbol_highlights = {
  File = "Identifier",
  Module = "Include",
  Namespace = "Include",
  Package = "Include",
  Class = "Type",
  Method = "Function",
  Property = "Identifier",
  Field = "Identifier",
  Constructor = "Special",
  Enum = "Type",
  Interface = "Type",
  Function = "Function",
  Variable = "Constant",
  Constant = "Constant",
  String = "String",
  Number = "Number",
  Boolean = "Boolean",
  Array = "Constant",
  Object = "Type",
  Key = "Type",
  Null = "Type",
  EnumMember = "Identifier",
  Struct = "Structure",
  Event = "Type",
  Operator = "Identifier",
  TypeParameter = "Identifier",
  Component = "Function",
  Fragment = "Constant",
  TypeAlias = "Type",
  Parameter = "Identifier",
  StaticMethod = "Function",
  Macro = "Function",
}

local function outline_symbol_icons()
  local icons = require("libs.icons").symbol
  local result = {}

  for kind, icon in pairs(icons) do
    result[kind] = {
      icon = icon,
      hl = symbol_highlights[kind] or "Identifier",
    }
  end

  return result
end

local function setup_options()
  local float = require("util.float")
  local icons = require("libs.icons")

  return {
    outline_window = {
      position = "right",
      split_command = "botright 32vsplit",
      width = 32,
      relative_width = false,
      wrap = false,
      focus_on_open = true,
      auto_close = false,
      auto_jump = false,
      show_cursorline = "focus_in_outline",
      winhl = float.panel_winhighlight(),
      no_provider_message = "No supported outline provider",
    },
    outline_items = {
      show_symbol_details = false,
      show_symbol_lineno = false,
      highlight_hovered_item = true,
      auto_set_cursor = true,
    },
    guides = {
      enabled = true,
      markers = {
        bottom = "└",
        middle = "├",
        vertical = icons.basic.indent,
        horizontal = "─",
      },
    },
    symbol_folding = {
      autofold_depth = 1,
      auto_unfold = {
        hovered = true,
        only = true,
      },
      markers = { icons.tree.collapsed, icons.tree.expanded },
    },
    preview_window = {
      auto_preview = false,
      border = float.border,
      winhl = float.float_winhighlight({
        CursorLine = "PmenuSel",
      }),
      winblend = 0,
    },
    providers = {
      priority = { "lsp", "markdown", "man" },
      markdown = {
        filetypes = { "markdown" },
      },
    },
    symbols = {
      icons = outline_symbol_icons(),
    },
  }
end

return {
  "hedyhli/outline.nvim",
  cmd = {
    "Outline",
    "OutlineOpen",
    "OutlineClose",
    "OutlineFocusOutline",
    "OutlineFocusCode",
    "OutlineFocus",
    "OutlineStatus",
    "OutlineFollow",
    "OutlineRefresh",
  },
  keys = {
    {
      "<leader>so",
      "<Cmd>Outline<CR>",
      desc = "Outline symbols",
    },
  },
  opts = setup_options,
}
