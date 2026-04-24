-- LSP：使用 Neovim 0.11+ 的 vim.lsp.config / vim.lsp.enable API
-- mason-lspconfig v2 的 automatic_enable 会自动调用 vim.lsp.enable

local servers = {
  lua_ls = {
    settings = {
      Lua = {
        completion = { callSnippet = "Replace" },
        diagnostics = { globals = { "vim" } },
        workspace = {
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file("", true),
        },
      },
    },
  },
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        cargo = { allFeatures = true },
      },
    },
  },
}

local function enable_inlay_hints(bufnr)
  if vim.lsp.inlay_hint and type(vim.lsp.inlay_hint.enable) == "function" then
    pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
  end
end

return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },
  dependencies = {
    { "williamboman/mason.nvim", opts = {} },
    "williamboman/mason-lspconfig.nvim",
    "saghen/blink.cmp",
  },
  config = function()
    vim.diagnostic.config({
      severity_sort = true,
      signs = true,
      underline = true,
      update_in_insert = false,
      virtual_text = {
        prefix = "●",
        source = false,
        spacing = 2,
        severity = { min = vim.diagnostic.severity.WARN },
      },
      float = { border = "rounded", source = "if_many" },
    })

    -- 所有 server 共享的默认 capabilities
    vim.lsp.config("*", {
      capabilities = require("blink.cmp").get_lsp_capabilities(),
    })

    for name, cfg in pairs(servers) do
      vim.lsp.config(name, cfg)
    end

    require("mason-lspconfig").setup({
      ensure_installed = vim.tbl_keys(servers),
      automatic_enable = true,
    })

    vim.api.nvim_create_autocmd("LspAttach", {
      group = vim.api.nvim_create_augroup("ConfigLspAttach", { clear = true }),
      callback = function(event)
        local client = vim.lsp.get_client_by_id(event.data.client_id)

        if client and client:supports_method("textDocument/inlayHint") then
          enable_inlay_hints(event.buf)
        end

        if vim.bo[event.buf].filetype == "markdown" then
          return
        end

        local map = function(mode, lhs, rhs, desc)
          vim.keymap.set(mode, lhs, rhs, { buffer = event.buf, desc = desc, silent = true })
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
  end,
}
