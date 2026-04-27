-- LSP：使用 Neovim 0.11+ 的 vim.lsp.config / vim.lsp.enable API
-- mason-lspconfig v2 的 automatic_enable 会自动调用 vim.lsp.enable

local servers = {
  lua_ls = {
    settings = {
      Lua = {
        completion = { callSnippet = "Replace" },
        diagnostics = { globals = { "vim" } },
        workspace = {
          -- 让 lua_ls 认识 Neovim runtime 下的 API 定义，减少 vim.* 误报。
          checkThirdParty = false,
          library = vim.api.nvim_get_runtime_file("", true),
        },
      },
    },
  },
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        -- Rust 项目默认启用所有 feature，避免条件编译下的符号缺失。
        cargo = { allFeatures = true },
      },
    },
  },
}

local function enable_inlay_hints(bufnr)
  -- 不同 Neovim 小版本的 inlay_hint API 曾有差异，用 pcall 保持兼容。
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
  },
  config = function()
    -- 只把 WARN 及以上诊断显示成行内虚拟文本，HINT/INFO 仍保留在 Trouble/浮窗里。
    -- 这样能减少日常编辑时的视觉噪音，但不会丢失诊断信息。
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

    -- 所有 server 共享的默认 capabilities：直接复用 blink.cmp 给出的能力声明，
    -- 与补全菜单实际支持的特性（snippet/resolve/labelDetails 等）保持一致。
    vim.lsp.config("*", {
      capabilities = require("blink.cmp").get_lsp_capabilities(nil, true),
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
          -- markdown 主要依赖 Treesitter/补全，不绑 LSP 跳转键，避免普通写作时误触。
          return
        end

        vim.schedule(function()
          if not vim.api.nvim_buf_is_valid(event.buf) then
            return
          end

          -- Neovim 0.11 会给 LSP 预置 gr* 系列键位；这里先删掉再按个人习惯重绑。
          -- 放进 schedule 是为了等内置绑定完成后再覆盖，避免顺序竞争。
          pcall(vim.keymap.del, "n", "grn", { buffer = event.buf })
          pcall(vim.keymap.del, "n", "grr", { buffer = event.buf })
          pcall(vim.keymap.del, "n", "gri", { buffer = event.buf })
          pcall(vim.keymap.del, "n", "gra", { buffer = event.buf })
          pcall(vim.keymap.del, "x", "gra", { buffer = event.buf })

          local map = function(mode, lhs, rhs, desc, opts)
            local keymap_opts = vim.tbl_extend("force", {
              buffer = event.buf,
              desc = desc,
              silent = true,
            }, opts or {})

            vim.keymap.set(mode, lhs, rhs, keymap_opts)
          end

          map("n", "K", vim.lsp.buf.hover, "LSP hover")
          map("n", "gd", vim.lsp.buf.definition, "Goto definition")
          map("n", "gr", "<Cmd>Trouble lsp_references toggle focus=true win.position=right<CR>", "References", { nowait = true })
          map("n", "gI", "<Cmd>Trouble lsp_implementations toggle focus=true win.position=right<CR>", "Goto implementation", { nowait = true })
          map("n", "<leader>rn", vim.lsp.buf.rename, "Rename")
          map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("n", "<leader>fd", "<Cmd>Trouble diagnostics toggle focus=true filter.buf=0 win.position=bottom<CR>", "Document diagnostics")
        end)
      end,
    })
  end,
}
