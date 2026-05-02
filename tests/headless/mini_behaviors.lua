local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)
vim.opt.updatecount = 0

local tmp_root = vim.fn.tempname()
vim.fn.delete(tmp_root, "rf")
vim.fn.mkdir(tmp_root, "p")
vim.env.XDG_DATA_HOME = tmp_root .. "/xdg-data"
vim.fn.mkdir(vim.fn.stdpath("data"), "p")

local function assert_eq(actual, expected, message)
  if actual ~= expected then
    error(string.format("%s\nexpected: %s\nactual: %s", message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function assert_true(value, message)
  if not value then
    error(message, 2)
  end
end

local function reset_modules(...)
  for _, name in ipairs({ ... }) do
    package.loaded[name] = nil
  end
end

local function temp_path(...)
  return vim.fs.joinpath(tmp_root, ...)
end

local function write_file(path, lines)
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  local ok = vim.fn.writefile(lines or { "x" }, path)
  assert_eq(ok, 0, "writefile should succeed: " .. path)
end

local tests = {}

function tests.recent_paths_are_unique_ordered_and_removable()
  reset_modules("plugins.mini.visits")

  local first = temp_path("recent", "first.txt")
  local second = temp_path("recent", "second.txt")
  write_file(first)
  write_file(second)

  local visits = require("plugins.mini.visits")
  visits.record_path(first)
  visits.record_path(second)
  visits.record_path(first)

  local items = visits.recent_paths_section(5)()
  assert_eq(#items, 2, "recent paths should be unique")
  assert_eq(items[1].recent_path, vim.fn.fnamemodify(first, ":p"), "newest repeated path should move to top")
  assert_eq(items[2].recent_path, vim.fn.fnamemodify(second, ":p"), "older path should remain after newest")

  assert_true(visits.remove_recent_path(first), "remove_recent_path should report removal")
  items = visits.recent_paths_section(5)()
  assert_eq(#items, 1, "removed path should disappear")
  assert_eq(items[1].recent_path, vim.fn.fnamemodify(second, ":p"), "remaining path should still be listed")

  assert_true(visits.remove_recent_path(second), "last recent path should be removable")
  items = visits.recent_paths_section(5)()
  assert_eq(items[1].name, "There are no recent paths yet", "empty recent paths should render a placeholder item")
end

function tests.starter_reuses_empty_placeholder_buffer()
  reset_modules("plugins.mini.starter", "plugins.mini.visits", "plugins.mini.sessions")

  local opened_buf
  local saved_session = false
  local closed_files = false

  package.loaded["plugins.mini.visits"] = {
    setup = function() end,
    recent_paths_section = function()
      return function()
        return {}
      end
    end,
    open_path = function() end,
  }
  package.loaded["plugins.mini.sessions"] = {
    write_current = function()
      saved_session = true
    end,
  }
  package.loaded["mini.files"] = {
    close = function()
      closed_files = true
      return true
    end,
  }
  package.loaded["mini.bufremove"] = {
    delete = function() end,
  }
  package.loaded["mini.starter"] = {
    setup = function() end,
    gen_hook = {
      aligning = function()
        return function() end
      end,
    },
    open = function(bufnr)
      opened_buf = bufnr
    end,
  }

  vim.cmd("silent! enew!")
  local placeholder = vim.api.nvim_get_current_buf()
  require("plugins.mini.starter").open()

  assert_true(saved_session, "starter should save current session before clearing")
  assert_true(closed_files, "starter should close mini.files before opening")
  assert_eq(opened_buf, placeholder, "starter should reuse the empty unnamed placeholder buffer")
end

function tests.starter_hides_hidden_empty_placeholders()
  reset_modules("plugins.mini.starter", "plugins.mini.visits", "plugins.mini.sessions", "mini.bufremove")

  local opened_buf

  package.loaded["plugins.mini.visits"] = {
    setup = function() end,
    recent_paths_section = function()
      return function()
        return {}
      end
    end,
    open_path = function() end,
  }
  package.loaded["plugins.mini.sessions"] = {
    write_current = function() end,
  }
  package.loaded["mini.files"] = {
    close = function()
      return true
    end,
  }
  package.loaded["mini.bufremove"] = {
    delete = function() end,
  }
  package.loaded["mini.starter"] = {
    setup = function() end,
    gen_hook = {
      aligning = function()
        return function() end
      end,
    },
    open = function(bufnr)
      opened_buf = bufnr
    end,
  }

  local file = temp_path("starter-special", "main.lua")
  write_file(file, { "print('ok')" })

  vim.cmd("silent! only")
  vim.cmd("edit " .. vim.fn.fnameescape(file))
  vim.cmd("vsplit")

  local special = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(0, special)
  vim.bo[special].buftype = "nofile"
  vim.bo[special].filetype = "specialstatus"
  vim.bo[special].buflisted = false

  require("plugins.mini.starter").open()

  assert_eq(opened_buf, nil, "starter should create its own buffer when current buffer is special")
  for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
    local is_hidden_empty = vim.bo[buf_id].buflisted
      and #vim.fn.win_findbuf(buf_id) == 0
      and vim.api.nvim_buf_get_name(buf_id) == ""
      and vim.bo[buf_id].buftype == ""
    assert_true(not is_hidden_empty, "starter should hide hidden empty placeholders")
  end
end

function tests.starter_hides_statusline_until_leave()
  reset_modules("plugins.mini.starter", "plugins.mini.visits", "plugins.mini.sessions", "lualine")

  package.loaded["plugins.mini.visits"] = {
    setup = function() end,
    recent_paths_section = function()
      return function()
        return {}
      end
    end,
    open_path = function() end,
  }
  package.loaded["mini.starter"] = {
    setup = function() end,
    gen_hook = {
      aligning = function()
        return function() end
      end,
    },
  }

  local original_laststatus = vim.o.laststatus
  vim.o.laststatus = 3

  require("plugins.mini.starter").setup()

  vim.cmd("silent! enew!")
  vim.api.nvim_exec_autocmds("User", {
    pattern = "MiniStarterOpened",
    modeline = false,
  })

  assert_eq(vim.o.laststatus, 0, "starter should hide the bottom statusline")

  vim.cmd("silent! enew!")
  vim.wait(100, function()
    return vim.o.laststatus == 3
  end)

  assert_eq(vim.o.laststatus, 3, "leaving starter should restore the previous statusline setting")
  vim.o.laststatus = original_laststatus
end

function tests.mini_files_opens_from_root_and_focuses_current_branch()
  reset_modules("plugins.mini.files")

  local project = temp_path("project")
  local nested = vim.fs.joinpath(project, "src")
  local file = vim.fs.joinpath(nested, "main.lua")
  write_file(file, { "print('ok')" })

  local opened_root
  local branch
  local focused_depth

  package.loaded["mini.files"] = {
    setup = function() end,
    close = function()
      return false
    end,
    open = function(path)
      opened_root = path
    end,
    set_branch = function(paths, opts)
      branch = paths
      focused_depth = opts.depth_focus
    end,
    get_explorer_state = function()
      return nil
    end,
  }

  vim.cmd("edit " .. vim.fn.fnameescape(file))
  require("plugins.mini.files").open(project)

  assert_eq(opened_root, vim.fs.normalize(project), "mini.files should open at requested root")
  assert_eq(branch[1], vim.fs.normalize(project), "branch should start at root")
  assert_eq(branch[#branch], vim.fs.normalize(nested), "branch should end at current file directory")
  assert_eq(focused_depth, #branch, "deepest branch should be focused")
end

function tests.mini_files_hides_reusable_target_placeholder()
  reset_modules("plugins.mini.files")

  local project = temp_path("placeholder-project")
  vim.fn.mkdir(project, "p")

  local target_win = vim.api.nvim_get_current_win()
  vim.cmd("silent! enew!")
  local placeholder = vim.api.nvim_get_current_buf()
  vim.bo[placeholder].buflisted = true

  package.loaded["mini.files"] = {
    setup = function() end,
    close = function()
      return false
    end,
    open = function() end,
    get_explorer_state = function()
      return { target_window = target_win }
    end,
  }

  require("plugins.mini.files").open(project)

  assert_eq(vim.bo[placeholder].buflisted, false, "mini.files should hide reusable empty target placeholders")
end

function tests.session_restore_preserves_requested_cwd()
  reset_modules("plugins.mini.sessions")

  local project = temp_path("restore-project")
  local other = temp_path("other-cwd")
  local session_dir = temp_path("sessions")
  vim.fn.mkdir(project, "p")
  vim.fn.mkdir(other, "p")
  vim.fn.mkdir(session_dir, "p")

  local read_name
  local read_opts
  package.loaded["mini.sessions"] = {
    config = { directory = session_dir },
    setup = function() end,
    read = function(name, opts)
      read_name = name
      read_opts = opts
      vim.api.nvim_set_current_dir(other)
    end,
    write = function() end,
    select = function() end,
  }

  vim.api.nvim_set_current_dir(project)
  local sessions = require("plugins.mini.sessions")
  assert_true(sessions.read_current({ notify = false, verbose = false }), "read_current should report success")

  assert_true(read_name:match("%.vim$") ~= nil, "session read should receive a session file name")
  assert_eq(read_opts.force, false, "session restore should not force by default")
  assert_eq(read_opts.verbose, false, "session restore should honor verbose=false")
  assert_eq(vim.fs.normalize(vim.fn.getcwd()), vim.fs.normalize(project), "read_current should restore cwd after reading old sessions")
  assert_eq(sessions.should_auto_restore(), false, "headless mode should not auto restore sessions")
end

local test_order = {
  "recent_paths_are_unique_ordered_and_removable",
  "starter_reuses_empty_placeholder_buffer",
  "starter_hides_hidden_empty_placeholders",
  "starter_hides_statusline_until_leave",
  "mini_files_opens_from_root_and_focuses_current_branch",
  "mini_files_hides_reusable_target_placeholder",
  "session_restore_preserves_requested_cwd",
}

local failures = {}
for _, name in ipairs(test_order) do
  local test = tests[name]
  local ok, err = xpcall(test, debug.traceback)
  if ok then
    print("ok - " .. name)
  else
    table.insert(failures, "not ok - " .. name .. "\n" .. err)
  end
end

vim.fn.delete(tmp_root, "rf")

if #failures > 0 then
  error(table.concat(failures, "\n\n"))
end

print("headless mini behavior checks passed")
