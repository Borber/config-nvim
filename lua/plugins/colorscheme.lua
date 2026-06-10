return {
  "sainnhe/everforest",
  lazy = false,
  priority = 1000,
  config = function()
    local float = require("util.float")
    local everforest = require("util.palette").everforest

    local function apply_highlights()
      float.apply_highlights()
      vim.api.nvim_set_hl(0, "LspInlayHint", { fg = everforest.muted, bg = "NONE", italic = true })
    end

    local function cleanup_generated_syntax()
      local colorscheme_path = vim.api.nvim_get_runtime_file("colors/everforest.vim", false)[1]
      if type(colorscheme_path) ~= "string" or colorscheme_path == "" then
        return
      end

      if vim.fn["everforest#syn_exists"](colorscheme_path) == 1 then
        vim.fn["everforest#syn_clean"](colorscheme_path, 0)
      end
    end

    vim.o.background = "dark"
    vim.g.everforest_background = "hard"
    -- better_performance 会把 after/syntax 生成回可写插件目录，污染本仓库；
    -- 这里直接关闭，并顺手清理历史生成物。
    vim.g.everforest_better_performance = 0
    vim.g.everforest_enable_italic = 1
    vim.g.everforest_inlay_hints_background = "none"
    vim.g.everforest_transparent_background = 1

    cleanup_generated_syntax()

    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ConfigThemeAppearance", { clear = true }),
      pattern = "everforest",
      callback = apply_highlights,
    })

    vim.cmd.colorscheme("everforest")
  end,
}
