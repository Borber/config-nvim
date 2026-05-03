-- LSP：使用 Neovim 0.11+ 的 vim.lsp.config / vim.lsp.enable API。
-- Mason 只负责安装和手动管理；LSP 本体等首个真实文件出现后再加载。

local function enable_inlay_hints(bufnr)
  if vim.lsp.inlay_hint and type(vim.lsp.inlay_hint.enable) == "function" then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

local function diagnostic_jump(count)
  return function()
    assert(vim.diagnostic.jump ~= nil, "vim.diagnostic.jump is required")
    vim.diagnostic.jump({ count = count, float = true })
  end
end

local function telescope_lsp_picker(name)
  -- 延迟 require Telescope，避免 LSP attach 时就加载 picker。
  return function()
    require("telescope.builtin")[name]()
  end
end

return {
  {
    "williamboman/mason.nvim",
    cmd = {
      "Mason",
      "MasonInstall",
      "MasonLog",
      "MasonUninstall",
      "MasonUninstallAll",
      "MasonUpdate",
    },
    opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    event = "User ConfigUiReady",
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      local registry = require("lsp")
      local servers = registry.servers()
      local diagnostics = require("plugins.lsp.diagnostics")

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
        float = { border = require("util.float").border, source = "if_many" },
      })

      for name, cfg in pairs(servers) do
        vim.lsp.config(name, cfg)
      end

      vim.lsp.enable(registry.names())

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("ConfigLspAttach", { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          diagnostics.wrap_handlers(client)

          if client and diagnostics.muted(event.buf, client) then
            diagnostics.reset(client.id, event.buf)
          end

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
            map("n", "K", function()
              vim.lsp.buf.hover({ border = require("util.float").border })
            end, "LSP hover")
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
  },
}
