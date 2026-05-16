local M = {}
local configured = false

-- ============================================
-- 分组线索
-- ============================================
local function leader_clues()
  return {
    { mode = "n", keys = "<Leader>b", desc = "+buffer" },
    { mode = "n", keys = "<Leader>c", desc = "+code" },
    { mode = "n", keys = "<Leader>f", desc = "+find" },
    { mode = "n", keys = "<Leader>g", desc = "+git" },
    { mode = "n", keys = "<Leader>j", desc = "+job" },
    { mode = "n", keys = "<Leader>m", desc = "+bookmark" },
    { mode = "n", keys = "<Leader>n", desc = "+notes" },
    { mode = "n", keys = "<Leader>q", desc = "+quit" },
    { mode = "n", keys = "<Leader>s", desc = "+symbol" },
    { mode = "n", keys = "<Leader>t", desc = "+terminal" },
    { mode = "n", keys = "<Leader>u", desc = "+ui" },

    { mode = "x", keys = "<Leader>c", desc = "+code" },
    { mode = "x", keys = "<Leader>f", desc = "+find" },
    { mode = "x", keys = "<Leader>g", desc = "+git" },
  }
end

local function localleader_clues()
  return {
    { mode = "n", keys = "<LocalLeader>m", desc = "+markdown" },
    { mode = "x", keys = "<LocalLeader>m", desc = "+markdown" },
  }
end

-- ============================================
-- 对外入口
-- ============================================
function M.setup()
  if configured then
    return
  end

  configured = true

  local clue = require("mini.clue")
  local float = require("util.float")

  clue.setup({
    clues = {
      leader_clues(),
      localleader_clues(),
    },
    triggers = {
      { mode = { "n", "x" }, keys = "<Leader>" },
      { mode = { "n", "x" }, keys = "<LocalLeader>" },
    },
    window = {
      delay = 0,
      config = {
        border = float.border,
        width = "auto",
      },
    },
  })
end

return M
