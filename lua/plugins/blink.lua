return {
  "saghen/blink.cmp",
  version = "1.*",
  event = "VeryLazy",
  opts = {
    enabled = function()
      return false
    end,
    fuzzy = {
      implementation = "prefer_rust",
    },
    cmdline = {
      enabled = true,
      keymap = {
        preset = "cmdline",
        ["<Tab>"] = { "show", "accept" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
      },
      sources = function()
        local cmdtype = vim.fn.getcmdtype()

        if cmdtype == "/" or cmdtype == "?" then
          return { "buffer" }
        end

        if cmdtype == ":" or cmdtype == "@" then
          return { "cmdline", "buffer" }
        end

        return {}
      end,
      completion = {
        ghost_text = {
          enabled = true,
        },
        menu = {
          auto_show = true,
        },
      },
    },
  },
}