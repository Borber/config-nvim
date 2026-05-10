local lifecycle = require("config.lifecycle")

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

local function workspace_symbol_display_location(path, lnum)
  if path == nil or path == "" then
    return "", nil
  end

  local normalized = vim.fs.normalize(path):gsub("\\", "/")
  local cwd = vim.fs.normalize(vim.uv.cwd() or vim.fn.getcwd()):gsub("\\", "/")
  local display_path = vim.fs.relpath(cwd, normalized) or vim.fn.fnamemodify(normalized, ":~")

  if lnum ~= nil and lnum > 0 then
    return display_path, tostring(lnum)
  end

  return display_path, nil
end

local function workspace_symbol_entry_maker(opts)
  opts = opts or {}

  local entry_display = require("telescope.pickers.entry_display")
  local icons = require("libs.icons")
  local make_entry = require("telescope.make_entry")
  local symbol_icons = icons.symbol

  -- 只改展示顺序：结果区聚焦符号本身，路径交给 preview 顶部显示。
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 2 },
      { remaining = true },
    },
  })

  return function(entry)
    local text = entry.text or ""
    local symbol_type, symbol_name = text:match("%[(.+)%]%s+(.*)")
    symbol_type = entry.kind or symbol_type or "Unknown"
    symbol_name = symbol_name or text
    local symbol_icon = symbol_icons[symbol_type] or icons.basic.file

    local display_path, display_lnum = workspace_symbol_display_location(entry.filename, entry.lnum)

    return make_entry.set_default_entry_mt({
      value = entry,
      ordinal = table.concat({ symbol_name, symbol_type, display_path, display_lnum or "" }, " "),
      display = function(item)
        return displayer({
          { item.symbol_icon, "TelescopeResultsComment" },
          item.symbol_name,
        })
      end,
      filename = entry.filename,
      lnum = entry.lnum,
      col = entry.col,
      symbol_icon = symbol_icon,
      symbol_name = symbol_name,
      symbol_type = symbol_type,
      display_path = display_path,
      display_lnum = display_lnum,
      start = entry.start,
      finish = entry.finish,
    }, opts)
  end
end

local function workspace_symbol_winbar(entry)
  local path = (entry.display_path or ""):gsub("%%", "%%%%")
  local lnum = entry.display_lnum or ""

  if path == "" then
    return ""
  end

  if lnum ~= "" then
    return path .. ":" .. lnum
  end

  return path
end

local symbol_preview_ns = vim.api.nvim_create_namespace("ConfigWorkspaceSymbolPreview")

local function workspace_symbol_jump(self, bufnr, entry)
  pcall(vim.api.nvim_buf_clear_namespace, bufnr, symbol_preview_ns, 0, -1)

  if entry.lnum == nil or entry.lnum <= 0 then
    return
  end

  pcall(vim.api.nvim_buf_add_highlight, bufnr, symbol_preview_ns, "TelescopePreviewLine", entry.lnum - 1, 0, -1)
  pcall(vim.api.nvim_win_set_cursor, self.state.winid, { entry.lnum, 0 })
  pcall(vim.api.nvim_win_call, self.state.winid, function()
    vim.cmd("normal! zz")
  end)
end

local function workspace_symbol_previewer()
  local conf = require("telescope.config").values
  local previewers = require("telescope.previewers")

  return previewers.new_buffer_previewer({
    title = "Symbol Preview",
    get_buffer_by_name = function(_, entry)
      return entry.filename
    end,
    define_preview = function(self, entry)
      if entry.filename == nil or entry.filename == "" then
        return
      end

      if self.state.winid ~= nil then
        pcall(function()
          vim.wo[self.state.winid].winbar = workspace_symbol_winbar(entry)
        end)
      end

      conf.buffer_previewer_maker(entry.filename, self.state.bufnr, {
        bufname = self.state.bufname,
        winid = self.state.winid,
        callback = function(bufnr)
          workspace_symbol_jump(self, bufnr, entry)
        end,
      })
    end,
  })
end

local function workspace_symbols_picker()
  return function()
    require("telescope.builtin").lsp_dynamic_workspace_symbols({
      entry_maker = workspace_symbol_entry_maker(),
      previewer = workspace_symbol_previewer(),
    })
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
    event = lifecycle.lazy_events.ui_ready,
    dependencies = { "williamboman/mason.nvim" },
    config = function()
      local registry = require("lsp")
      local diagnostics = require("plugins.lsp.diagnostics")

      -- 只把 WARN 及以上诊断显示成行内虚拟文本，HINT/INFO 仍保留在 Trouble/浮窗里。
      -- 这样能减少日常编辑时的视觉噪音，但不会丢失诊断信息。
      vim.diagnostic.config({
        severity_sort = true,
        signs = true,
        underline = true,
        update_in_insert = true,
        virtual_text = {
          prefix = "●",
          source = false,
          spacing = 2,
          severity = { min = vim.diagnostic.severity.WARN },
        },
        float = { border = require("util.float").border, source = "if_many" },
      })

      registry.configure()
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
            -- 结构/诊断入口留在 <leader>s 下；真正的全文查找仍归到 Telescope 的 <leader>f 系列。
            map("n", "<leader>sd", "<Cmd>Trouble diagnostics toggle focus=true filter.buf=0 win.position=bottom<CR>", "Document diagnostics")
            map("n", "<leader>sD", "<Cmd>Trouble diagnostics toggle focus=true win.position=bottom<CR>", "Workspace diagnostics")
            map("n", "<leader>ss", workspace_symbols_picker(), "Workspace symbols")
            -- 诊断跳转保留原生 [d/]d 手感，并在跳转后弹出诊断浮窗。
            map("n", "]d", diagnostic_jump(1), "Next diagnostic")
            map("n", "[d", diagnostic_jump(-1), "Previous diagnostic")
          end)
        end,
      })
    end,
  },
}
