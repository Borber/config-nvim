local function editor_width()
  return vim.o.columns
end

local function min_width(columns)
  return function()
    return editor_width() > columns
  end
end

local function compact_width(minimum, maximum)
  return function()
    local columns = editor_width()
    return columns > minimum and columns <= maximum
  end
end

local function filename_components()
  return {
    {
      "filename",
      path = 1,
      shorting_target = function()
        local columns = editor_width()
        if columns > 140 then
          return 50
        end
        if columns > 100 then
          return 40
        end
        return 25
      end,
      cond = min_width(90),
    },
    {
      "filename",
      path = 4,
      shorting_target = 0,
      cond = compact_width(60, 90),
    },
    {
      "filename",
      path = 0,
      shorting_target = 0,
      cond = function()
        return editor_width() <= 60
      end,
    },
  }
end

return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  event = "VeryLazy",
  opts = {
    options = {
      theme = "auto",
      globalstatus = true,
      always_divide_middle = false,
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
      disabled_filetypes = {
        statusline = { "ministarter" },
      },
    },
    sections = {
      lualine_a = { "mode" },
      lualine_b = {
        {
          "branch",
          cond = min_width(100),
        },
        {
          "diagnostics",
          cond = min_width(120),
        },
      },
      lualine_c = filename_components(),
      lualine_x = {
        {
          "filetype",
          cond = min_width(80),
        },
      },
      lualine_y = {
        {
          "progress",
          cond = min_width(120),
        },
      },
      lualine_z = { "location" },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = filename_components(),
      lualine_x = { "location" },
      lualine_y = {},
      lualine_z = {},
    },
    extensions = { "lazy", "quickfix", "man" },
  },
}