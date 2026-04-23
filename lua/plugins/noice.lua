return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  opts = {
    cmdline = {
      enabled = true,
      view = "cmdline_popup",
      format = {
        cmdline = {
          title = "   ",
        },
      },
    },
    views = {
      cmdline_popup = {
        size = {
          min_width = 30,
        },
      },
    },
    messages = {
      enabled = true,
      view = "mini",
      view_error = "mini",
      view_warn = "mini",
      view_search = false,
    },
    popupmenu = {
      enabled = false,
    },
    lsp = {
      progress = {
        enabled = false,
      },
    },
    presets = {
      bottom_search = true,
      command_palette = false,
      long_message_to_split = true,
      lsp_doc_border = false,
    },
  },
}