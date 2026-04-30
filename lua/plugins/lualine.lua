local function min_cols(n)
  return function()
    return vim.o.columns > n
  end
end

local mode_labels = {
  NORMAL = "N",
  ["O-PENDING"] = "O",
  VISUAL = "V",
  ["V-LINE"] = "VL",
  ["V-BLOCK"] = "VB",
  SELECT = "S",
  ["S-LINE"] = "SL",
  ["S-BLOCK"] = "SB",
  INSERT = "I",
  REPLACE = "R",
  ["V-REPLACE"] = "VR",
  COMMAND = "C",
  EX = "EX",
  MORE = "M",
  CONFIRM = "CF",
  SHELL = "SH",
  TERMINAL = "T",
}

local function short_mode(mode)
  return mode_labels[mode] or mode:sub(1, 1)
end

return {
  "nvim-lualine/lualine.nvim",
  event = "VeryLazy",
  opts = {
    options = {
      theme = "auto",
      globalstatus = true,
      always_divide_middle = false,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      disabled_filetypes = { statusline = { "ministarter" } },
    },
    sections = {
      lualine_a = {
        {
          "mode",
          fmt = short_mode,
        },
      },
      lualine_b = {
        {
          "branch",
          icon = "",
          color = { gui = "bold" },
          cond = min_cols(100),
        },
        {
          "diagnostics",
          sources = { "nvim_diagnostic" },
          symbols = { error = " ", warn = " ", info = " " },
          cond = min_cols(120),
        },
      },
      lualine_c = {},
      lualine_x = {},
      lualine_y = { { "filetype", cond = min_cols(80) } },
      lualine_z = { { "progress", cond = min_cols(120) }  },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {},
      lualine_x = { "location" },
      lualine_y = {},
      lualine_z = {},
    },
    -- 顶部只展示 buffer 列表；原生 tab/tabby 不再承担文件切换职责。
    tabline = {
      lualine_a = {
        {
          function()
            return ""
          end,
          padding = { left = 1, right = 1 },
        },
      },
      lualine_b = {
        {
          "buffers",
          mode = 0,
          show_modified_status = true,
          max_length = function()
            return vim.o.columns
          end,
          symbols = {
            modified = " ●",
            alternate_file = "",
            directory = "",
          },
        },
      },
      lualine_c = {},
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    extensions = { "lazy", "quickfix", "man" },
  },
}
