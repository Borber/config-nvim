local M = {}
local configured = false

local explorer = require("plugins.mini.files.explorer")
local starter_mode = require("plugins.mini.files.starter_mode")

function M.setup()
  if configured then
    return
  end

  configured = true

  -- 这里仍然只负责 mini.files 本体的通用设置；具体交互分发给 explorer / starter_mode。
  require("mini.files").setup({
    mappings = {
      go_in_plus = "<CR>",
    },
    options = {
      use_as_default_explorer = false,
    },
    windows = {
      preview = true,
      width_preview = 60,
    },
  })

  require("plugins.hop.line_jump").register(explorer.handle_hop_line_jump)

  local group = vim.api.nvim_create_augroup("ConfigMiniFiles", { clear = true })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MiniFilesBufferCreate",
    callback = function(args)
      local buf_id = args.data.buf_id

      -- 这些映射只绑定到 mini.files 的临时 buffer，离开文件树后不会污染普通编辑区。
      vim.keymap.set("n", "<Esc>", function()
        require("mini.files").close()
      end, {
        buffer = buf_id,
        desc = "Close explorer",
        silent = true,
      })

      vim.keymap.set("n", "<CR>", explorer.open_entry, {
        buffer = buf_id,
        desc = "Open entry",
        silent = true,
      })

      vim.keymap.set("n", "l", explorer.open_entry, {
        buffer = buf_id,
        desc = "Open entry",
        silent = true,
      })

      starter_mode.attach_buffer(buf_id)
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MiniFilesExplorerClose",
    callback = starter_mode.disable,
  })

  vim.api.nvim_create_autocmd("WinEnter", {
    group = group,
    -- 文件树有多列时，跟随当前窗口同步 depth_focus，避免焦点看起来和实际窗口不一致。
    callback = explorer.sync_focus_to_current_window,
  })
end

function M.toggle()
  M.setup()

  starter_mode.disable()

  local minifiles = require("mini.files")
  if minifiles.close() then
    return
  end

  explorer.open_root()
end

function M.open(path)
  M.setup()

  local root = path or vim.fn.getcwd()
  require("mini.files").close()
  -- Starter 的 Open 进入的是“选择路径”模式，先打开再允许 <S-CR> 最终确认。
  starter_mode.enable()
  explorer.open_root(root)
end

function M.handle_hop_line_jump(jump_target)
  return explorer.handle_hop_line_jump(jump_target)
end

return M
