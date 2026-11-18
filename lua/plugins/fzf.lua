local function fzf()
  return require("fzf-lua")
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
      "<leader>fg",
      function()
        fzf().live_grep()
      end,
      desc = "Live grep",
    },
    {
      "<leader>fw",
      function()
        fzf().live_grep({ search = vim.fn.expand("<cword>") })
      end,
      desc = "Search word",
    },
    {
      "<leader>fw",
      function()
        local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
        local text = table.concat(lines, "\n")
        fzf().live_grep({ search = text ~= "" and text or vim.fn.expand("<cword>") })
      end,
      desc = "Search selection",
      mode = "x",
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
        fd_opts = "--color=never --type f --hidden --follow --exclude .git",
      },
      grep = {
        rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob !.git/*",
      },
    })

    float.apply_highlights()
  end,
}
