local function selected_text()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_row, start_col = start_pos[2], start_pos[3]
  local end_row, end_col = end_pos[2], end_pos[3]

  if start_row == 0 or end_row == 0 then
    return nil
  end

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_text(0, start_row - 1, start_col - 1, end_row - 1, end_col, {})
  local text = table.concat(lines, "\n")

  return text ~= "" and text or nil
end

local function fzf()
  return require("fzf-lua")
end

local daily_file_excludes = {
  ".git",
  ".cache",
  ".next",
  ".turbo",
  "build",
  "coverage",
  "dist",
  "node_modules",
  "target",
}

local function fd_opts(excludes)
  local opts = { "--color=never", "--type f", "--hidden", "--follow" }
  for _, exclude in ipairs(excludes) do
    table.insert(opts, "--exclude " .. exclude)
  end

  return table.concat(opts, " ")
end

local daily_fd_opts = fd_opts(daily_file_excludes)
local full_fd_opts = fd_opts({ ".git" })

local function live_grep_current_text()
  return function()
    fzf().live_grep({
      search = selected_text() or vim.fn.expand("<cword>"),
    })
  end
end

return {
  "ibhagwan/fzf-lua",
  cmd = "FzfLua",
  keys = {
    {
      "<leader>/",
      function()
        fzf().blines()
      end,
      desc = "Search buffer",
    },
    {
      "<leader>ff",
      function()
        fzf().files()
      end,
      desc = "Find files",
    },
    {
      "<leader>fF",
      function()
        fzf().files({ fd_opts = full_fd_opts })
      end,
      desc = "Find files (all)",
    },
    {
      "<leader>fg",
      function()
        fzf().live_grep()
      end,
      desc = "Live grep",
    },
    {
      "<leader>fw",
      live_grep_current_text(),
      desc = "Search word",
      mode = { "n", "x" },
    },
    {
      "<leader>,",
      function()
        fzf().buffers()
      end,
      desc = "Buffers",
    },
    {
      "<leader>fh",
      function()
        fzf().helptags()
      end,
      desc = "Help tags",
    },
    {
      "<leader>fr",
      function()
        fzf().oldfiles()
      end,
      desc = "Recent files",
    },
    {
      "<leader>fH",
      function()
        fzf().command_history({
          winopts = {
            width = 0.4,
            height = 0.45,
            backdrop = false,
            preview = { hidden = "hidden" },
          },
        })
      end,
      desc = "Command history",
    },
  },
  config = function()
    local float = require("util.float")

    fzf().setup({
      winopts = {
        width = 0.87,
        height = 0.8,
        border = float.border,
        backdrop = false,
        winblend = 0,
        treesitter = {
          fzf_colors = false,
        },
        preview = {
          border = float.border,
          layout = "horizontal",
          horizontal = "right:55%",
          winopts = {
            winblend = 0,
          },
        },
      },
      fzf_opts = {
        ["--layout"] = "reverse",
        ["--info"] = "inline",
      },
      -- fzf 二进制内部的当前项和 gutter 不完全受 Neovim 浮窗高亮控制，需要显式传入颜色。
      fzf_colors = {
        fg = { "fg", "FzfLuaFzfNormal" },
        bg = { "bg", "FzfLuaFzfNormal" },
        ["fg+"] = { "fg", { "FzfLuaFzfCursorLine", "FzfLuaFzfNormal" } },
        ["bg+"] = { "bg", "FzfLuaFzfCursorLine" },
        hl = { "fg", "FzfLuaFzfMatch" },
        ["hl+"] = { "fg", "FzfLuaFzfMatch" },
        gutter = { "bg", "FzfLuaFzfGutter" },
        info = { "fg", "FzfLuaFzfInfo" },
        pointer = { "fg", "FzfLuaFzfPointer" },
        marker = { "fg", "FzfLuaFzfMarker" },
        prompt = { "fg", "FzfLuaFzfPrompt" },
        query = { "fg", "FzfLuaFzfQuery", "regular" },
        border = { "fg", "FzfLuaFzfBorder" },
        separator = { "fg", "FzfLuaFzfSeparator" },
        scrollbar = { "fg", "FzfLuaFzfScrollbar" },
      },
      keymap = {
        fzf = {
          ["alt-j"] = "down",
          ["alt-k"] = "up",
        },
      },
      files = {
        fd_opts = daily_fd_opts,
      },
      grep = {
        rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob !.git/*",
      },
    })

    float.apply_highlights()
  end,
}
