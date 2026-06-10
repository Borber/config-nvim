local lifecycle = require("config.lifecycle")

return {
  "folke/noice.nvim",
  event = lifecycle.lazy_events.ui_ready,
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  config = function(_, opts)
    require("patches.noice_signature").apply()

    require("noice").setup(opts)
  end,
  opts = function()
    local float = require("util.float")

    return {
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
          border = float.noice_border(),
          win_options = {
            winhighlight = float.float_winhighlight({
              IncSearch = "",
              CurSearch = "",
            }),
          },
        },
        cmdline_input = {
          border = float.noice_border(),
        },
        popup = {
          border = {
            style = float.border,
          },
        },
        hover = {
          border = float.noice_border({ 0, 2 }),
        },
        mini = {
          border = {
            style = float.border,
          },
          win_options = {
            winblend = 0,
            winhighlight = float.float_winhighlight({
              IncSearch = "",
              CurSearch = "",
            }),
          },
        },
        confirm = {
          border = vim.tbl_extend("force", float.noice_border(), {
            text = { top = " Confirm " },
          }),
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
        hover = {
          enabled = false,
        },
        progress = {
          enabled = true,
        },
      },
      presets = {
        bottom_search = true,
        command_palette = false,
        long_message_to_split = true,
        lsp_doc_border = true,
      },
    }
  end,
}
