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
          library = { vim.env.VIMRUNTIME },
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
  -- C/C++ 只启用通用 clangd 能力，不写项目路径或 Chromium 专用探测。
  clangd = {
    cmd = {
      "clangd",
      "--background-index",             -- 后台索引，提升跨文件跳转和引用查找体验
      "--completion-style=detailed",     -- 补全项保留更多类型/签名信息
      "--header-insertion=never",        -- 不让 clangd 自动插入 include，避免误改代码
    },
    init_options = {
      clangdFileStatus = true,           -- 允许 clangd 回报索引/解析状态
    },
  },
  -- 常见 Web / 配置文件语言服务器先纳入 Mason 管理；具体项目能力由各 server 自己判断。
  ts_ls = {},
  eslint = {},
  jsonls = {},
  bashls = {},
  taplo = {},
}

local function enable_inlay_hints(bufnr)
  -- 不同 Neovim 小版本的 inlay_hint API 曾有差异，用 pcall 保持兼容。
  if vim.lsp.inlay_hint and type(vim.lsp.inlay_hint.enable) == "function" then
    pcall(vim.lsp.inlay_hint.enable, true, { bufnr = bufnr })
  end
end

local function diagnostic_jump(count)
  -- Neovim 0.11+ 使用 diagnostic.jump；旧版本回退到 goto_next/goto_prev。
  return function()
    if vim.diagnostic.jump ~= nil then
      vim.diagnostic.jump({ count = count, float = true })
      return
    end

    local fallback = count > 0 and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
    fallback({ float = true })
  end
end

local function telescope_lsp_picker(name)
  -- 延迟 require Telescope，避免 LSP attach 时就加载 picker。
  return function()
    require("telescope.builtin")[name]()
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

          local map = function(mode, lhs, rhs, desc, opts)
            local keymap_opts = vim.tbl_extend("force", {
              buffer = event.buf,
              desc = desc,
              silent = true,
            }, opts or {})

            vim.keymap.set(mode, lhs, rhs, keymap_opts)
          end

          -- 基础 LSP 跳转：定义、声明、类型定义、引用和实现分开保留。
          map("n", "K", vim.lsp.buf.hover, "LSP hover")
          map("n", "gd", vim.lsp.buf.definition, "Goto definition")
          -- C/C++ 等语言里声明和定义经常分离：gD 去声明，gd 去实现/定义。
          map("n", "gD", vim.lsp.buf.declaration, "Goto declaration")
          -- gy 用来看变量/表达式背后的类型定义，适合强类型项目里追类型来源。
          map("n", "gy", vim.lsp.buf.type_definition, "Goto type definition")
          map("n", "grr", "<Cmd>Trouble lsp_references toggle focus=true win.position=right<CR>", "References")
          map("n", "gri", "<Cmd>Trouble lsp_implementations toggle focus=true win.position=right<CR>", "Goto implementation")
          -- 修改类动作统一放在 <leader>c 下：rename 改符号名，code action 做快速修复/重构。
          map("n", "<leader>cr", vim.lsp.buf.rename, "Rename symbol")
          map({ "n", "x" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
          -- 查找类入口统一放在 <leader>f 下；Trouble 承担诊断列表，Telescope 承担符号列表。
          map("n", "<leader>fd", "<Cmd>Trouble diagnostics toggle focus=true filter.buf=0 win.position=bottom<CR>", "Document diagnostics")
          map("n", "<leader>fD", "<Cmd>Trouble diagnostics toggle focus=true win.position=bottom<CR>", "Workspace diagnostics")
          map("n", "<leader>fs", telescope_lsp_picker("lsp_document_symbols"), "Document symbols")
          map("n", "<leader>fS", telescope_lsp_picker("lsp_dynamic_workspace_symbols"), "Workspace symbols")
          -- 诊断跳转保留原生 [d/]d 手感，并在跳转后弹出诊断浮窗。
          map("n", "]d", diagnostic_jump(1), "Next diagnostic")
          map("n", "[d", diagnostic_jump(-1), "Previous diagnostic")
        end)
      end,
    })
  end,
}
