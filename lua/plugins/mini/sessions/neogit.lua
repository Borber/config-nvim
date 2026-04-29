local M = {}

local function collect_status_windows()
  -- session restore 可能恢复出旧的 NeogitStatus buffer；先记录窗口和当时 cwd，
  -- 后续再按实际 git root 重新打开，避免状态页停在过期仓库上下文里。
  local windows = {}

  for _, win_id in ipairs(vim.api.nvim_list_wins()) do
    local buf_id = vim.api.nvim_win_get_buf(win_id)

    if vim.bo[buf_id].filetype == "NeogitStatus" then
      table.insert(windows, {
        win_id = win_id,
        cwd = vim.api.nvim_win_call(win_id, vim.fn.getcwd),
      })
    end
  end

  return windows
end

function M.refresh_status_windows()
  -- 逐个刷新 Neogit 状态窗口；单个窗口失败不影响整个 session restore。
  for _, window in ipairs(collect_status_windows()) do
    if vim.api.nvim_win_is_valid(window.win_id) then
      pcall(function()
        local git = require("util.git")
        local main_file = require("util.main_file")
        vim.api.nvim_set_current_win(window.win_id)

        local repo_cwd = git.root_from(window.cwd)
          or git.root_from_buffer(main_file.current_buf())
        if not repo_cwd then
          return
        end

        local opts = { cwd = repo_cwd, kind = "replace", no_expand = true }
        require("neogit").open(opts)
        require("util.neogit_loading").start(opts, window.win_id)
      end)
    end
  end
end

return M
