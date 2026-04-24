local function markdown_link_target()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  local from = 1

  while from <= #line do
    local start_col, end_col, target = line:find("%[[^%]]-%]%((.-)%)", from)
    if start_col == nil then
      break
    end

    if col >= start_col and col <= end_col then
      return target
    end

    from = end_col + 1
  end

  local start_col, end_col, autolink = line:find("<(https?://[^>]+)>")
  if start_col ~= nil and col >= start_col and col <= end_col then
    return autolink
  end
end

local function open_markdown_target()
  local target = markdown_link_target()
  if target == nil or target == "" then
    vim.cmd.normal({ args = { "K" }, bang = true })
    return
  end

  if target:match("^https?://") then
    vim.ui.open(target)
    return
  end

  local path = target:gsub("#.*$", "")
  if path == "" then
    return
  end

  local base = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  local resolved = vim.fs.normalize(vim.fs.joinpath(base, path))

  vim.cmd("edit " .. vim.fn.fnameescape(resolved))
end

return {
  {
    "YousefHadder/markdown-plus.nvim",
    ft = { "markdown" },
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("ConfigMarkdownKeys", { clear = true }),
        pattern = "markdown",
        callback = function(event)
          local map = function(mode, lhs, rhs, desc)
            vim.keymap.set(mode, lhs, rhs, {
              buffer = event.buf,
              desc = desc,
              silent = true,
              remap = type(rhs) == "string" and rhs:match("^<Plug>") ~= nil,
            })
          end
          map("n", "K", open_markdown_target, "Open markdown link")
          -- markdown-plus 默认映射已整体禁用（见下方 opts.keymaps.enabled=false），
          -- 这里手工保留唯一需要的：<localleader>mx 切换 checkbox（n/x 模式）。
          map({ "n", "x" }, "<localleader>mx", "<Plug>(MarkdownPlusToggleCheckbox)", "Toggle checkbox")
        end,
      })
    end,
    opts = {
      -- 关掉 markdown-plus 自带的所有默认 keymap（避免 <localleader>h* / <localleader>t* 冲突）。
      -- 需要用到的功能通过 <Plug>(MarkdownPlus...) 手工绑定。
      keymaps = { enabled = false },
    },
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    ft = { "markdown" },
    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    opts = {
      restart_highlighter = true,
      render_modes = true,
      anti_conceal = {
        enabled = true,
        disabled_modes = { 'n', 'v', 'V', 'c', 't' },
        above = 0,
        below = 0,
      },
      win_options = {
        conceallevel = {
          default = 0,
          rendered = 3,
        },
        concealcursor = {
          default = '',
          rendered = 'n',
        },
      },
      heading = {
        sign = false,
        icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      },
      code = {
        sign = false,
        style = "full",
        border = "thin",
        left_pad = 1,
        right_pad = 1,
        language_pad = 1,
      },
      bullet = {
        icons = { "●", "○", "◆", "◇" },
      },
      pipe_table = {
        preset = "round",
      },
      completions = {
        lsp = { enabled = true },
      },
    },
  },
}
