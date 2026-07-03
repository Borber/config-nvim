local function cmdline_menu_position()
  local cmdtype = vim.fn.getcmdtype()
  local is_search = cmdtype == "/" or cmdtype == "?"

  -- Noice 是命令行位置的唯一来源；取不到位置就直接报错，避免静默猜错补全菜单坐标。
  local position = require("noice.api").get_cmdline_position()
  assert(position and position.screenpos, "Noice cmdline position is unavailable")

  local row = position.screenpos.row - 1
  if is_search then
    row = math.max(row, 0)
  elseif position.win and vim.api.nvim_win_is_valid(position.win) then
    local win_config = vim.api.nvim_win_get_config(position.win)
    if win_config.relative ~= "" then
      row = row + 1
    end
  end

  return { row, math.max(position.screenpos.col - 4, 0) }
end

local function with_blink_build_env(callback)
  if vim.uv.os_uname().sysname ~= "Darwin" then
    return callback()
  end

  local original_rustflags = vim.env.RUSTFLAGS
  local required_flags = "-C link-arg=-undefined -C link-arg=dynamic_lookup"

  if not original_rustflags or original_rustflags == "" then
    vim.env.RUSTFLAGS = required_flags
  elseif not original_rustflags:find("dynamic_lookup", 1, true) then
    vim.env.RUSTFLAGS = original_rustflags .. " " .. required_flags
  end

  local ok, err = pcall(callback)
  vim.env.RUSTFLAGS = original_rustflags

  if not ok then
    error(err)
  end
end

return {
  "saghen/blink.cmp",
  event = { "InsertEnter", "CmdlineEnter" },
  dependencies = {
    "saghen/blink.lib",
    "rafamadriz/friendly-snippets",
    "milanglacier/minuet-ai.nvim",
  },
  build = function()
    with_blink_build_env(function()
      require("blink.cmp").build():pwait(60000)
    end)
  end,
  config = function(_, opts)
    -- 覆盖 blink 内部的 accept preview，实现多行候选的临时预览。
    -- 这个入口属于内部模块，升级 blink 后如果预览异常，优先检查这里。
    require("patches.blink_preview").apply()
    local blink = require("blink.cmp")
    blink.setup(opts)

    local function show_minuet()
      blink.show({ providers = { "minuet" } })
    end

    vim.keymap.set("i", "<M-y>", show_minuet, { desc = "Minuet AI completion" })
  end,
  opts = function()
    local float = require("util.float")

    return {
      keymap = {
        preset = "super-tab",
        ["<M-j>"] = { "select_next", "fallback" },
        ["<M-k>"] = { "select_prev", "fallback" },
        ["<Down>"] = { "select_next", "fallback" },
        ["<Up>"] = { "select_prev", "fallback" },
        ["<C-n>"] = { "select_next", "fallback" },
        ["<C-p>"] = { "select_prev", "fallback" },
        -- 滚动右侧文档窗口；文档窗未展开时回退到默认按键行为，不影响菜单显示。
        ["<C-u>"] = { "scroll_documentation_up", "fallback" },
        ["<C-d>"] = { "scroll_documentation_down", "fallback" },
      },
      completion = {
        trigger = {
          show_on_insert = true,
          prefetch_on_insert = false,
          show_in_snippet = false,
        },
        menu = {
          border = float.border,
          winhighlight = float.menu_winhighlight(),
          cmdline_position = cmdline_menu_position,
        },
        -- 选中候选时自动打开右侧详情窗，LSP/普通补全沿用 blink 原生文档渲染。
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 50,
          update_delay_ms = 50,
          window = {
            desired_min_width = 48,
            desired_min_height = 12,
            border = float.border,
            winhighlight = float.float_winhighlight({
              EndOfBuffer = "NormalFloat",
            }),
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
        preset = "default",
      },
      sources = {
        default = { "lsp", "minuet", "path", "buffer" },
        per_filetype = {
          markdown = { inherit_defaults = true, "snippets" },
        },
        providers = {
          buffer = {
            opts = {
              get_bufnrs = function()
                if vim.bo.filetype == "markdown" then
                  -- Markdown buffer 经常同时打开笔记/长文；只取当前 buffer，避免补全串词。
                  return { vim.api.nvim_get_current_buf() }
                end

                -- 其他文件从所有可见窗口收集 buffer，让分屏中的上下文也参与补全。
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
          minuet = {
            name = "minuet",
            module = "minuet.blink",
            async = true,
            timeout_ms = 3000,
            score_offset = 50,
          },
        },
      },

      fuzzy = {
        implementation = "prefer_rust_with_warning",
      },

      signature = {
        window = {
          border = float.border,
          winhighlight = float.float_winhighlight(),
        },
      },
      cmdline = {
        enabled = true,
        keymap = {
          preset = "cmdline",
          ["<Tab>"] = { "show", "accept" },
          ["<M-j>"] = { "select_next", "fallback" },
          ["<M-k>"] = { "select_prev", "fallback" },
          ["<Up>"] = { "select_prev", "fallback" },
          ["<Down>"] = { "select_next", "fallback" },
        },
        completion = {
          menu = {
            auto_show = true,
            draw = {
              columns = { { "label", "label_description", gap = 1 } },
            },
          },
          ghost_text = { enabled = true },
        },
      },
    }
  end,
}
