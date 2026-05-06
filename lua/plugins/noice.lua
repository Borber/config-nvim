return {
  "folke/noice.nvim",
  event = "User ConfigUiReady",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  config = function(_, opts)
    -- noice 的签名帮助和 blink 的补全菜单都可能占用同一块浮窗视线。
    -- 当补全菜单已经显示时，临时压住 signature popup，避免两个浮窗抢焦点。
    local function blink_menu_visible()
      local blink = package.loaded["blink.cmp"]
      return blink ~= nil and blink.is_menu_visible ~= nil and blink.is_menu_visible()
    end

    local signature = require("noice.lsp.signature")
    if not rawget(signature, "_config_nvim_blink_guarded") then
      -- 只 patch 一次，防止插件配置被重复执行时多次包裹同一个函数。
      local original_check = signature.check
      local original_on_signature = signature.on_signature

      signature.check = function()
        if blink_menu_visible() then
          return
        end

        return original_check()
      end

      signature.on_signature = function(...)
        if blink_menu_visible() then
          return
        end

        return original_on_signature(...)
      end

      rawset(signature, "_config_nvim_blink_guarded", true)
    end

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
      routes = {
        {
          filter = {
            find = "[Ww]aka[Tt]ime",
          },
          opts = {
            skip = true,
          },
        },
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
