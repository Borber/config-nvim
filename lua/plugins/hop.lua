local special_filetypes = {
  ["TelescopePrompt"] = true,
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
  local opts = setmetatable({
    multi_windows = true,
    visual_mode = "V",
  }, { __index = hop.opts })

  local mode = vim.api.nvim_get_mode().mode
  if mode ~= "n" and mode ~= "nt" then
    opts.multi_windows = false
  end

  hop.hint_with_regex(require("hop.jump_regex").by_line_start(), opts, function(jump_target)
    if require("plugins.hop.line_jump").handle(jump_target) then
      return
    end

    hop.move_cursor_to(jump_target, opts)
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
  "wsdjeg/hop.nvim",
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
    keys = "werasdfcvjlk",
    jump_on_sole_occurrence = true,
    dim_unmatched = false,
  },
}

-- 给 Neogit 这类 buffer-local 映射复用同一套上下文分发。
spec.hint_by_context = hint_by_context

return spec
