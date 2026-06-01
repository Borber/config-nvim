local special_filetypes = {
  fzf = true,
  minifiles = true,
  noice = true,
  notify = true,
  overseer = true,
  qf = true,
  starter = true,
  trouble = true,
}

local hop_palette = require("util.palette").everforest

local function apply_highlights()
  local set_hl = vim.api.nvim_set_hl

  set_hl(0, "HopNextKey", { fg = hop_palette.base, bg = hop_palette.red, bold = true })
  set_hl(0, "HopNextKey1", { fg = hop_palette.base, bg = hop_palette.gold, bold = true })
  set_hl(0, "HopNextKey2", { fg = hop_palette.base, bg = hop_palette.purple, bold = true })
  set_hl(0, "HopPreview", { fg = hop_palette.base, bg = hop_palette.aqua, bold = true })
  set_hl(0, "HopCursor", { fg = hop_palette.base, bg = hop_palette.orange, bold = true })
  set_hl(0, "HopUnmatched", { fg = hop_palette.muted })
end

local function is_normal_file_buffer(buf_id)
  return vim.bo[buf_id].buftype == "" and vim.bo[buf_id].modifiable and not special_filetypes[vim.bo[buf_id].filetype]
end

local function hint_words()
  require("hop").hint_words({ multi_windows = false })
end

local function hint_lines_across_windows()
  local hop = require("hop")
  local jump_target = require("hop.jump_target")
  local opts = setmetatable({
    multi_windows = true,
    visual_mode = "V",
  }, { __index = hop.opts })

  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "n" and mode ~= "nt" then
    opts.multi_windows = false
  end

  hop.hint_with_callback(jump_target.line_start_generator(false), opts, function(target)
    if require("plugins.hop.line_jump").handle(target) then
      return
    end

    hop.move_cursor_to(target, opts)
  end)
end

-- 普通编辑区保持 HopWord；列表/树状界面更适合按可见行跳转。
local function hint_by_context()
  if is_normal_file_buffer(vim.api.nvim_get_current_buf()) then
    hint_words()
    return
  end

  hint_lines_across_windows()
end

local spec = {
  "Borber/hop.nvim",
  keys = {
    {
      "s",
      hint_by_context,
      mode = { "n", "x", "o" },
      desc = "Hop by context",
      silent = true,
    },
  },
  opts = {
    keys = "werasdfcvuiojkl",
    jump_on_sole_occurrence = true,
    dim_unmatched = false,
    hl_mode = "replace",
  },
  config = function(_, opts)
    require("hop").setup(opts)
    apply_highlights()
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("ConfigHopHighlights", { clear = true }),
      callback = apply_highlights,
    })
  end,
}

-- 给 Neogit 这类 buffer-local 映射复用同一套上下文分发。
spec.hint_by_context = hint_by_context

return spec
