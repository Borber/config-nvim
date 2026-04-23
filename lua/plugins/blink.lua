return {
  "saghen/blink.cmp",
  version = "1.*",
  event = "VeryLazy",
  dependencies = {
    "L3MON4D3/LuaSnip",
  },
  opts = {
    enabled = function()
      return true
    end,
    keymap = {
      preset = "super-tab",
      ["<M-j>"] = { "select_next", "fallback" },
      ["<M-k>"] = { "select_prev", "fallback" },
    },
    completion = {
      trigger = {
        show_in_snippet = false,
      },
    },
    snippets = {
      preset = "luasnip",
    },
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