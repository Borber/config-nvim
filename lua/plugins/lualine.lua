local function min_cols(n)
  return function()
    return vim.o.columns > n
  end
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
      lualine_a = { "mode" },
      lualine_b = {
        { "branch",      cond = min_cols(100) },
        { "diagnostics", cond = min_cols(120) },
      },
      lualine_c = {
        {
          function()
            return require("util.main_file").status_name()
          end,
          shorting_target = 40,
        },
      },
      lualine_x = { { "filetype", cond = min_cols(80) } },
      lualine_y = { { "progress", cond = min_cols(120) } },
      lualine_z = { "location" },
    },
    inactive_sections = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {
        function()
          return require("util.main_file").status_name()
        end,
      },
      lualine_x = { "location" },
      lualine_y = {},
      lualine_z = {},
    },
    extensions = { "lazy", "quickfix", "man" },
  },
}
