return {
  "folke/noice.nvim",
  event = "VeryLazy",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  config = function(_, opts)
    local function blink_menu_visible()
      local blink = package.loaded["blink.cmp"]
      return blink ~= nil and blink.is_menu_visible ~= nil and blink.is_menu_visible()
    end

    local signature = require("noice.lsp.signature")
    if not signature._config_nvim_blink_guarded then
      local original_check = signature.check
      local original_on_signature = signature.on_signature

      signature.check = function(...)
        if blink_menu_visible() then
          return
        end

        return original_check(...)
      end

      signature.on_signature = function(...)
        if blink_menu_visible() then
          return
        end

        return original_on_signature(...)
      end

      signature._config_nvim_blink_guarded = true
    end

    require("noice").setup(opts)
  end,
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