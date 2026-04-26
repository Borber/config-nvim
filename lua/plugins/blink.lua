-- 提取候选项开头的标识符，用来判断 Copilot 是否只是把当前符号继续展开。
local function leading_identifier(label)
  if type(label) ~= "string" then
    return nil
  end

  return label:match("^[%a_][%w_]*") or label:match("^[%w_]+")
end

-- 当 Copilot 候选只是对已有符号做扩写时，让本地/LSP 的纯符号项优先展示。
local function prefer_plain_symbol_over_copilot(item_a, item_b)
  local a_is_copilot = item_a.source_id == "copilot"
  local b_is_copilot = item_b.source_id == "copilot"
  if a_is_copilot == b_is_copilot then
    return nil
  end

  local copilot_item = a_is_copilot and item_a or item_b
  local other_item = a_is_copilot and item_b or item_a
  local copilot_label = copilot_item.label or ""
  local other_label = other_item.label or ""

  if other_label ~= "" and vim.startswith(copilot_label, other_label) then
    return not a_is_copilot
  end

  local copilot_head = leading_identifier(copilot_label)
  local other_head = leading_identifier(other_label)
  if copilot_head ~= nil and copilot_head == other_head then
    return not a_is_copilot
  end

  return nil
end

local function preview_multiline_completion(item)
  local text_edits = require("blink.cmp.lib.text_edits")
  local text_edit = text_edits.get_from_item(item)

  if item.insertTextFormat == vim.lsp.protocol.InsertTextFormat.Snippet then
    local expanded_snippet = require("blink.cmp.sources.snippets.utils").safe_parse(text_edit.newText)
    text_edit.newText = expanded_snippet and tostring(expanded_snippet) or text_edit.newText
  end

  local original_cursor = vim.api.nvim_win_get_cursor(0)
  local undo_text_edit = text_edits.get_undo_text_edit(text_edit)
  text_edits.apply(text_edit)

  if vim.api.nvim_get_mode().mode ~= "c" then
    vim.api.nvim_win_set_cursor(0, original_cursor)
  end

  return undo_text_edit, nil
end

return {
  "saghen/blink.cmp",
  version = "1.*",
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = {
    "L3MON4D3/LuaSnip",
    "fang2hou/blink-copilot",
    {
      -- 关闭 Copilot 自带面板和内联建议，统一走 blink 的候选菜单。
      "zbirenbaum/copilot.lua",
      cmd = "Copilot",
      event = "InsertEnter",
      opts = {
        panel = {
          enabled = false,
        },
        suggestion = {
          enabled = false,
        },
        filetypes = {
          markdown = true,
        },
        server_opts_overrides = {
          settings = {
            advanced = {
              inlineSuggestCount = 4,
            },
          },
        },
      },
    },
  },
  config = function(_, opts)
    package.loaded["blink.cmp.completion.accept.preview"] = preview_multiline_completion
    require("blink.cmp").setup(opts)
  end,
  opts = {
    keymap = {
      preset = "super-tab",
      ["<M-j>"] = { "select_next", "fallback" },
      ["<M-k>"] = { "select_prev", "fallback" },
      -- 滚动右侧文档窗口；文档窗未展开时回退到默认按键行为，不影响菜单显示。
      ["<C-u>"] = { "scroll_documentation_up", "fallback" },
      ["<C-d>"] = { "scroll_documentation_down", "fallback" },
    },
    completion = {
      trigger = {
        show_on_insert = true,
        show_in_snippet = false,
      },
      -- 选中候选时自动打开右侧详情窗，LSP/普通补全沿用 blink 原生文档渲染。
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 50,
        update_delay_ms = 50,
        window = {
          desired_min_width = 48,
          desired_min_height = 12,
          max_width = 96,
          max_height = 24,
          direction_priority = {
            menu_north = { "e", "w", "n", "s" },
            menu_south = { "e", "w", "s", "n" },
          },
        },
      },
    },
    snippets = {
      preset = "luasnip",
    },
    sources = {
      default = { "lsp", "copilot", "path", "buffer" },
      per_filetype = {
        markdown = { inherit_defaults = true, "snippets" },
      },
      providers = {
        buffer = {
          opts = {
            get_bufnrs = function()
              if vim.bo.filetype == "markdown" then
                return { vim.api.nvim_get_current_buf() }
              end

              return vim
                .iter(vim.api.nvim_list_wins())
                :map(function(win)
                  return vim.api.nvim_win_get_buf(win)
                end)
                :filter(function(buf)
                  return vim.bo[buf].buftype ~= "nofile"
                end)
                :totable()
            end,
          },
        },
        copilot = {
          name = "copilot",
          module = "blink-copilot",
          -- 只做轻微加权，避免 Copilot 抢过本地/LSP 的精确候选。
          score_offset = 30,
          async = true,
          opts = {
            debounce = 100,
            max_completions = 4,
            max_attempts = 5,
          },
        },
      },
    },
    fuzzy = {
      implementation = "prefer_rust",
      -- 先执行自定义比较器，再回退到 blink 默认的精确度/分数排序。
      sorts = { prefer_plain_symbol_over_copilot, "exact", "score", "sort_text" },
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
        menu = { auto_show = true },
        ghost_text = { enabled = true },
      },
    },
  },
}
