local function lsp_capabilities()
  return require("blink.cmp").get_lsp_capabilities()
end

local function enable_inlay_hints(bufnr)
  if not vim.lsp.inlay_hint or type(vim.lsp.inlay_hint.enable) ~= "function" then
    return
  end

  local ok = pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
  if ok then
    return
  end

  pcall(vim.lsp.inlay_hint.enable, bufnr, true)
end

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
    "saghen/blink.cmp",
  },
  config = function()
    local lspconfig = require("lspconfig")
    local mason = require("mason")
    local mason_lspconfig = require("mason-lspconfig")

    mason.setup()

    vim.diagnostic.config({
      severity_sort = true,
      signs = true,
      underline = true,
      update_in_insert = false,
      virtual_text = {
        prefix = "●",
        source = false,
        spacing = 2,
        severity = {
          min = vim.diagnostic.severity.WARN,
        },
      },
      float = {
        border = "rounded",
        source = "if_many",
      },
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("ConfigLspAttach", { clear = true }),
      callback = function(event)
        local client = event.data and vim.lsp.get_client_by_id(event.data.client_id) or nil

        if client and client.supports_method and client:supports_method("textDocument/inlayHint") then
          enable_inlay_hints(event.buf)
        end

        if vim.bo[event.buf].filetype == "markdown" then
          return
        end

        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, {
            buffer = event.buf,
            desc = desc,
            silent = true,
          })
        end

        map("n", "K", vim.lsp.buf.hover, "LSP hover")
        map("n", "gd", vim.lsp.buf.definition, "Goto definition")
        map("n", "gr", "<Cmd>Trouble lsp_references toggle focus=true win.position=right<CR>", "References")
        map("n", "gI", "<Cmd>Trouble lsp_implementations toggle focus=true win.position=right<CR>", "Goto implementation")
        map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
        map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
        map("n", "<leader>fd", "<Cmd>Trouble diagnostics toggle focus=true filter.buf=0 win.position=bottom<CR>", "Document diagnostics")
      end,
    })

    mason_lspconfig.setup({
      automatic_installation = true,
      ensure_installed = {
        "lua_ls",
        "rust_analyzer",
      },
      handlers = {
        function(server_name)
          lspconfig[server_name].setup({
            capabilities = lsp_capabilities(),
          })
        end,
        ["lua_ls"] = function()
          lspconfig.lua_ls.setup({
            capabilities = lsp_capabilities(),
            settings = {
              Lua = {
                completion = {
                  callSnippet = "Replace",
                },
                diagnostics = {
                  globals = { "vim" },
                },
                workspace = {
                  checkThirdParty = false,
                  library = vim.api.nvim_get_runtime_file("", true),
                },
              },
            },
          })
        end,
        ["rust_analyzer"] = function()
          lspconfig.rust_analyzer.setup({
            capabilities = lsp_capabilities(),
            settings = {
              ["rust-analyzer"] = {
                cargo = {
                  allFeatures = true,
                },
              },
            },
          })
        end,
      },
    })
  end,
}