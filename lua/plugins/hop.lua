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
  },
}

-- 给特殊 buffer-local 映射复用同一套上下文分发。
spec.hint_by_context = hint_by_context

return spec
