local function key_icons()
  local ic = require("libs.icons")

  return {
    bookmark = { icon = ic.ui.bookmark, color = "yellow" },
    buffer = { icon = ic.basic.file, color = "cyan" },
    code = { icon = ic.ui.code, color = "orange" },
    explorer = { icon = ic.ui.explorer, color = "cyan" },
    find = { icon = ic.search.find, color = "green" },
    git = { icon = ic.git.icon, color = "orange" },
    keys = { icon = ic.ui.keys, color = "purple" },
    markdown = { icon = ic.ui.markdown, color = "blue" },
    notes = { icon = ic.basic.file, color = "blue" },
    quit = { icon = ic.ui.quit, color = "red" },
    session = { icon = ic.ui.session, color = "azure" },
    terminal = { icon = ic.ui.terminal, color = "red" },
  }
end

local function show_prefix(keys)
  -- 走 which-key 自己的前缀状态机，避免单独 <Space> 被当成普通移动键执行。
  return function()
    require("which-key").show({ keys = keys })
  end
end

return {
  "folke/which-key.nvim",
  -- UI ready 后第一批加载，优先保证按键提示可用。
  event = "User ConfigUiReady",
  opts = function()
    local icons = key_icons()
    local float = require("util.float")

    return {
      preset = "helix",
      delay = 0,
      win = {
        border = float.border,
      },
      spec = {
        { "<leader>e", icon = icons.explorer, desc = "Explorer" },
        { "<leader>f", icon = icons.find, group = "find" },
        { "<leader>g", icon = icons.git, group = "git" },
        { "<leader>j", icon = { icon = "J", color = "green" }, group = "job" },
        { "<leader>k", icon = icons.keys, group = "keys" },
        { "<leader>m", icon = icons.bookmark, group = "bookmark" },
        { "<leader>n", icon = icons.notes, group = "notes" },
        { "<leader>b", icon = icons.buffer, group = "buffer" },
        { "<leader>c", icon = icons.code, group = "code" },
        { "<leader>q", icon = icons.quit, group = "quit" },
        { "<leader>s", icon = icons.session, group = "session" },
        { "<leader>t", icon = icons.terminal, group = "terminal" },
        { "<leader>?", icon = icons.buffer, desc = "Buffer keymaps" },
        { "<localleader>m", icon = icons.markdown, group = "markdown" },
      },
    }
  end,
  keys = {
    -- lazy.nvim 先注册全局兜底；which-key 自动 trigger 重建时，第一下前缀键仍能被接住。
    {
      "<leader>",
      show_prefix("<leader>"),
      mode = { "n", "x", "o" },
      nowait = true,
      silent = true,
      desc = "which-key-trigger leader",
    },
    {
      "<localleader>",
      show_prefix("<localleader>"),
      mode = { "n", "x", "o" },
      nowait = true,
      silent = true,
      desc = "which-key-trigger localleader",
    },
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer keymaps",
    },
  },
}
