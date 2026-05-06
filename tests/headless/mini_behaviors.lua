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

local function normal_map(buf_id, lhs)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf_id, "n")) do
    if map.lhs == lhs then
      return map
    end
  end
end

local function reset_modules(...)
  local names = {}
  for _, name in ipairs({ ... }) do
    names[#names + 1] = name
  end

  -- 新拆出来的子模块也一并清掉，避免旧缓存让测试误判为“还在用旧实现”。
  for loaded_name in pairs(package.loaded) do
    for _, target in ipairs(names) do
      local prefix = target .. "."
      if loaded_name == target or loaded_name:sub(1, #prefix) == prefix then
        package.loaded[loaded_name] = nil
        break
      end
    end
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

local function hop_action()
  return require("plugins.hop").keys[1][2]
end

local function stub_visits(overrides)
  local visits = vim.tbl_extend("force", {
    setup = function() end,
    recent_paths_section = function()
      return function()
        return {}
      end
    end,
    open_path = function() end,
  }, overrides or {})

  package.loaded["plugins.mini.visits"] = visits
  return visits
end

local function stub_mini_starter(overrides)
  local capture = {}
  local starter = vim.tbl_extend("force", {
    setup = function(opts)
      capture.opts = opts
    end,
    gen_hook = {
      aligning = function()
        return function() end
      end,
    },
  }, overrides or {})

  package.loaded["mini.starter"] = starter
  return capture
end

local tests = {}

function tests.recent_projects_are_unique_ordered_and_removable()
  reset_modules("plugins.mini.visits")

  local first = temp_path("recent", "first-project")
  local second = temp_path("recent", "second-project")
  vim.fn.mkdir(first, "p")
  vim.fn.mkdir(second, "p")

  local visits = require("plugins.mini.visits")
  visits.record_path(first)
  visits.record_path(second)
  visits.record_path(first)

  local items = visits.recent_paths_section(5)()
  assert_eq(#items, 2, "recent paths should be unique")
  assert_eq(items[1].recent_path, require("libs.path").canonical_absolute(first), "newest repeated path should move to top")
  assert_eq(items[2].recent_path, require("libs.path").canonical_absolute(second), "older path should remain after newest")

  assert_true(visits.remove_recent_path(first), "remove_recent_path should report removal")
  items = visits.recent_paths_section(5)()
  assert_eq(#items, 1, "removed path should disappear")
  assert_eq(items[1].recent_path, require("libs.path").canonical_absolute(second), "remaining path should still be listed")

  assert_true(visits.remove_recent_path(second), "last recent path should be removable")
  items = visits.recent_paths_section(5)()
  assert_eq(items[1].name, "There are no recent projects yet", "empty recent paths should render a placeholder item")
end

function tests.recent_projects_record_current_cwd_after_late_setup()
  reset_modules("plugins.mini.visits")

  local original_v = vim.v
  local original_cwd = vim.fn.getcwd()
  local ok, err = xpcall(function()
    local project = temp_path("startup-recent-project")
    vim.fn.mkdir(project, "p")
    vim.api.nvim_set_current_dir(project)

    local store = vim.fn.stdpath("data") .. "/starter-recent-paths.json"
    vim.fn.delete(store)

    vim.v = setmetatable({}, {
      __index = function(_, key)
        if key == "vim_did_enter" then
          return 1
        end
        return original_v[key]
      end,
      __newindex = function(_, key, value)
        original_v[key] = value
      end,
    })

    require("plugins.mini.visits").setup()
    vim.v = original_v

    local lines = vim.fn.readfile(store)
    local decoded = vim.json.decode(table.concat(lines, "\n"))
    assert_eq(decoded[1], require("libs.path").canonical_absolute(project), "late visits.setup should record current cwd project")
  end, debug.traceback)

  vim.v = original_v
  pcall(vim.api.nvim_set_current_dir, original_cwd)
  pcall(vim.api.nvim_del_augroup_by_name, "ConfigRecentProjects")
  vim.cmd("silent! argdelete *")

  if not ok then
    error(err, 0)
  end
end

function tests.recent_projects_record_false_skips_project_record()
  reset_modules("plugins.mini.visits", "plugins.mini.sessions", "plugins.mini.files")

  local original_cwd = vim.fn.getcwd()
  local ok, err = xpcall(function()
    local config = temp_path("record-false-project")
    vim.fn.mkdir(config, "p")

    local store = vim.fn.stdpath("data") .. "/starter-recent-paths.json"
    vim.fn.delete(store)

    package.loaded["plugins.mini.sessions"] = {
      has_current = function()
        return false
      end,
    }
    package.loaded["plugins.mini.files"] = {
      open = function() end,
    }

    local visits = require("plugins.mini.visits")
    visits.open_path(config, { record = false })

    vim.wait(150)

    assert_eq(vim.fn.filereadable(store), 0, "record=false should not write a recent project")
  end, debug.traceback)

  pcall(vim.api.nvim_set_current_dir, original_cwd)
  reset_modules("plugins.mini.sessions", "plugins.mini.files")

  if not ok then
    error(err, 0)
  end
end

function tests.recent_projects_open_path_records_project()
  reset_modules("plugins.mini.visits", "plugins.mini.sessions", "plugins.mini.files")

  local original_cwd = vim.fn.getcwd()
  local ok, err = xpcall(function()
    local project = temp_path("open-path-record-project")
    vim.fn.mkdir(project, "p")

    local store = vim.fn.stdpath("data") .. "/starter-recent-paths.json"
    vim.fn.delete(store)

    package.loaded["plugins.mini.sessions"] = {
      has_current = function()
        return false
      end,
    }
    package.loaded["plugins.mini.files"] = {
      open = function() end,
    }

    require("plugins.mini.visits").open_path(project)

    local lines = vim.fn.readfile(store)
    local decoded = vim.json.decode(table.concat(lines, "\n"))
    assert_eq(decoded[1], require("libs.path").canonical_absolute(project), "open_path should record explicit project opens")
  end, debug.traceback)

  pcall(vim.api.nvim_set_current_dir, original_cwd)
  reset_modules("plugins.mini.sessions", "plugins.mini.files")

  if not ok then
    error(err, 0)
  end
end

function tests.mini_setup_initializes_visits_for_startup_paths()
  reset_modules("plugins.mini", "plugins.mini.visits", "plugins.mini.sessions")

  local visits_setup = false
  local ok, err = xpcall(function()
    local project = temp_path("mini-startup-project")
    vim.fn.mkdir(project, "p")
    vim.cmd("args " .. vim.fn.fnameescape(project))

    package.loaded["plugins.mini.visits"] = {
      setup = function()
        visits_setup = true
      end,
    }
    package.loaded["plugins.mini.sessions"] = {
      setup = function() end,
      has_current = function()
        return false
      end,
    }

    require("plugins.mini").config()
    assert_true(visits_setup, "mini setup should initialize visits when Neovim starts with path arguments")
  end, debug.traceback)

  vim.cmd("silent! argdelete *")
  reset_modules("plugins.mini", "plugins.mini.visits", "plugins.mini.sessions")
  pcall(vim.api.nvim_del_augroup_by_name, "ConfigMiniUi")
  pcall(vim.api.nvim_del_augroup_by_name, "ConfigMiniBackground")
  pcall(vim.api.nvim_del_augroup_by_name, "ConfigMiniEditing")

  if not ok then
    error(err, 0)
  end
end

function tests.starter_reuses_empty_placeholder_buffer()
  reset_modules("plugins.mini.starter", "plugins.mini.visits", "plugins.mini.sessions")

  local opened_buf
  local saved_session = false
  local closed_files = false

  stub_visits()
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
  stub_mini_starter({
    open = function(bufnr)
      opened_buf = bufnr
    end,
  })

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

  stub_visits()
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
  stub_mini_starter({
    open = function(bufnr)
      opened_buf = bufnr
    end,
  })

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

function tests.starter_keeps_global_statusline_unchanged()
  reset_modules("plugins.mini.starter", "plugins.mini.visits", "plugins.mini.sessions")

  stub_visits()
  stub_mini_starter()

  local original_laststatus = vim.o.laststatus
  vim.o.laststatus = 3

  require("plugins.mini.starter").setup()

  vim.cmd("silent! enew!")
  vim.api.nvim_exec_autocmds("User", {
    pattern = "MiniStarterOpened",
    modeline = false,
  })

  assert_eq(vim.o.laststatus, 3, "starter should leave global statusline ownership to lualine")
  vim.o.laststatus = original_laststatus
end

function tests.starter_initial_content_is_available_before_background()
  reset_modules("plugins.mini.starter", "plugins.mini.visits", "plugins.mini.sessions", "lazy", "lazy.stats", "libs.icons", "mini.files", "mini.bufremove")

  local background_ready = vim.g.config_background_ready
  vim.g.config_background_ready = nil

  local setup_called = false
  local stats = {
    loaded = 7,
    count = 42,
  }
  local cputime = 12.345

  stub_visits({
    setup = function()
      setup_called = true
    end,
    recent_paths_section = function(limit)
      assert_eq(limit, 10, "starter should request the configured recent path limit")
      return function()
        return {
          {
            name = "Project",
            action = "",
            recent_path = temp_path("project"),
            section = "Recent projects",
          },
        }
      end
    end,
  })
  package.loaded["lazy"] = {
    stats = function()
      return stats
    end,
  }
  package.loaded["lazy.stats"] = {
    cputime = function()
      return cputime
    end,
  }
  package.loaded["libs.icons"] = {
    ui = {
      rocket = "R",
    },
  }
  local starter = stub_mini_starter({
    open = function() end,
  })
  package.loaded["plugins.mini.sessions"] = {
    write_current = function() end,
  }
  package.loaded["mini.files"] = {
    close = function() end,
  }
  package.loaded["mini.bufremove"] = {
    delete = function() end,
  }

  local starter_module = require("plugins.mini.starter")
  starter_module.setup({ autoopen = true })

  local items = starter.opts.items[1]()
  assert_true(setup_called, "starter should initialize visits before background work")
  assert_eq(items[1].section, "Recent projects", "recent paths should render before delayed footer content")
  assert_eq(starter.opts.footer(), "R Loaded 7/42 plugins in 12.35 ms", "startup footer should render before background work")

  stats.loaded = 25
  cputime = 27464.444
  assert_eq(starter.opts.footer(), "R Loaded 7/42 plugins in 12.35 ms", "startup footer should keep the first startup snapshot")

  starter_module.open()
  assert_eq(starter.opts.footer(), "", "manual starter reopen should hide the startup-only footer")

  reset_modules("lazy", "lazy.stats", "libs.icons")
  vim.g.config_background_ready = background_ready
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

function tests.mini_files_does_not_install_local_hop_mapping()
  reset_modules("plugins.mini.files", "mini.files")

  local buf_id = vim.api.nvim_create_buf(false, true)

  package.loaded["mini.files"] = {
    setup = function() end,
  }

  require("plugins.mini.files").setup()
  vim.api.nvim_exec_autocmds("User", {
    pattern = "MiniFilesBufferCreate",
    data = { buf_id = buf_id },
    modeline = false,
  })

  assert_eq(normal_map(buf_id, "s"), nil, "mini.files buffer should not install local Hop mapping")
end

function tests.mini_files_focus_tracks_entered_directory_window()
  reset_modules("plugins.mini.files", "mini.files")

  local project = temp_path("focus-project")
  local src = vim.fs.joinpath(project, "src")
  local preview = vim.fs.joinpath(src, "auth")
  vim.fn.mkdir(preview, "p")

  vim.cmd("silent! only")

  local project_buf = vim.api.nvim_create_buf(false, true)
  local preview_buf = vim.api.nvim_create_buf(false, true)

  local project_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(project_win, project_buf)
  vim.cmd("vsplit")
  local preview_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(preview_win, preview_buf)

  local requested_depths = {}
  local state = {
    branch = { project, src, preview },
    depth_focus = 2,
    windows = {
      { win_id = project_win, path = project },
      { win_id = preview_win, path = preview },
    },
  }

  package.loaded["mini.files"] = {
    setup = function() end,
    get_explorer_state = function()
      return state
    end,
    set_branch = function(_, opts)
      table.insert(requested_depths, opts.depth_focus)
      state.depth_focus = opts.depth_focus
    end,
  }

  require("plugins.mini.files").setup()

  vim.api.nvim_set_current_win(project_win)
  assert_eq(requested_depths[#requested_depths], 1, "entering parent directory window should update focus depth")

  state.depth_focus = 2
  vim.api.nvim_set_current_win(preview_win)
  assert_eq(requested_depths[#requested_depths], 3, "entering preview directory window should update focus depth")
end

function tests.hop_global_mapping_uses_words_in_normal_file_buffer()
  reset_modules("plugins.hop", "plugins.hop.line_jump", "hop", "hop.jump_target")

  vim.cmd("silent! enew!")
  vim.bo.buftype = ""
  vim.bo.filetype = "lua"
  vim.bo.modifiable = true

  local word_opts

  package.loaded["hop"] = {
    opts = {},
    hint_words = function(opts)
      word_opts = opts
    end,
    hint_with_callback = function()
      error("normal file buffers should not use line hints")
    end,
  }

  hop_action()()

  assert_eq(word_opts.multi_windows, false, "normal file HopWord should stay in the current window")
end

function tests.hop_global_mapping_uses_registered_line_jump_handler_in_special_buffer()
  reset_modules("plugins.hop", "plugins.hop.line_jump", "hop", "hop.jump_target")

  vim.cmd("silent! enew!")
  vim.bo.filetype = "minifiles"

  local jump_target = {
    window = vim.api.nvim_get_current_win(),
    cursor = { row = 2, col = 0 },
  }
  local opts_used
  local handled_target
  local moved_target

  package.loaded["hop.jump_target"] = {
    line_start_generator = function(skip_whitespace)
      assert_eq(skip_whitespace, false, "Hop mapping should use raw line starts")
      return "line-start-generator"
    end,
  }
  package.loaded["hop"] = {
    opts = {
      keys = "asdf",
      jump_on_sole_occurrence = false,
      dim_unmatched = false,
    },
    hint_words = function()
      error("special buffers should not use HopWord")
    end,
    hint_with_callback = function(generator, opts, callback)
      assert_eq(generator, "line-start-generator", "Hop mapping should use line hints")
      opts_used = opts
      callback(jump_target)
    end,
    move_cursor_to = function(jump_target)
      moved_target = jump_target
    end,
  }

  require("plugins.hop.line_jump").register(function(target)
    handled_target = target
    return true
  end)

  hop_action()()

  assert_eq(opts_used.multi_windows, true, "Hop mapping should keep cross-window hints in normal mode")
  assert_eq(handled_target, jump_target, "Hop mapping should let registered handlers consume line jumps")
  assert_eq(moved_target, nil, "handled line jump should not also move with Hop")
end

function tests.mini_files_hop_line_jump_opens_preview_file()
  reset_modules("plugins.mini.files", "mini.files")

  local file = temp_path("hop-preview-open", "main.lua")
  write_file(file, { "one", "two", "three" })

  local preview_win = vim.api.nvim_get_current_win()
  local closed_files = false

  package.loaded["mini.files"] = {
    get_explorer_state = function()
      return {
        windows = {
          { win_id = preview_win, path = file },
        },
      }
    end,
    close = function()
      closed_files = true
      return true
    end,
  }

  local handled = require("plugins.mini.files").handle_hop_line_jump({
    window = preview_win,
    cursor = { row = 2, col = 0 },
  })

  assert_true(handled, "mini.files should handle file preview line jumps")
  assert_true(closed_files, "preview line jump should close mini.files before opening file")
  assert_eq(vim.fs.normalize(vim.api.nvim_buf_get_name(0)), vim.fs.normalize(file), "preview line jump should open file")
  assert_eq(vim.api.nvim_win_get_cursor(0)[1], 2, "preview line jump should keep selected line")
end

function tests.neogit_status_s_stages_only_stageable_file_rows()
  reset_modules("plugins.neogit", "neogit.buffers.status", "plugins.hop")

  vim.cmd("silent! enew!")
  local status_buf = vim.api.nvim_get_current_buf()
  local selection = {
    section = { name = "unstaged" },
    item = { name = "main.lua" },
  }
  local cursor = {
    file = { name = "main.lua" },
    hunk = nil,
  }
  local staged = false
  local hopped = false

  local status = {
    buffer = {
      handle = status_buf,
      ui = {
        get_selection = function()
          return selection
        end,
        get_cursor_location = function()
          return cursor
        end,
      },
    },
    _action = function(_, name)
      assert_eq(name, "n_stage", "Neogit s should reuse the normal stage action")
      return function()
        staged = true
      end
    end,
  }

  package.loaded["neogit.buffers.status"] = {
    instance = function()
      return status
    end,
  }
  package.loaded["plugins.hop"] = {
    hint_by_context = function()
      hopped = true
    end,
  }

  local map = require("plugins.neogit").opts().mappings.status.s
  local function assert_s_behavior(expected_stage, message)
    staged = false
    hopped = false

    map()

    assert_eq(staged, expected_stage, message)
    assert_eq(hopped, not expected_stage, message .. " should use the opposite Hop fallback")
  end

  assert_s_behavior(true, "s on an unstaged file row should stage it")

  selection.section.name = "untracked"
  assert_s_behavior(true, "s on an untracked file row should stage it")

  cursor.hunk = { name = "hunk" }
  assert_s_behavior(false, "s inside a file hunk should not stage")

  cursor.hunk = nil
  selection.section.name = "staged"
  assert_s_behavior(false, "s outside stageable sections should not stage")
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

function tests.session_options_stay_lightweight()
  reset_modules("plugins.mini.sessions")

  local session_dir = temp_path("lightweight-sessions")
  vim.fn.mkdir(session_dir, "p")

  package.loaded["mini.sessions"] = {
    config = { directory = session_dir },
    setup = function() end,
    read = function() end,
    write = function() end,
    select = function() end,
  }

  require("plugins.mini.sessions").setup()

  assert_eq(vim.o.sessionoptions, "buffers", "sessions should not persist local options such as fold state")
end

local test_order = {
  "recent_projects_are_unique_ordered_and_removable",
  "recent_projects_record_current_cwd_after_late_setup",
  "recent_projects_record_false_skips_project_record",
  "recent_projects_open_path_records_project",
  "mini_setup_initializes_visits_for_startup_paths",
  "starter_reuses_empty_placeholder_buffer",
  "starter_hides_hidden_empty_placeholders",
  "starter_keeps_global_statusline_unchanged",
  "starter_initial_content_is_available_before_background",
  "mini_files_opens_from_root_and_focuses_current_branch",
  "mini_files_hides_reusable_target_placeholder",
  "mini_files_does_not_install_local_hop_mapping",
  "mini_files_focus_tracks_entered_directory_window",
  "hop_global_mapping_uses_words_in_normal_file_buffer",
  "hop_global_mapping_uses_registered_line_jump_handler_in_special_buffer",
  "mini_files_hop_line_jump_opens_preview_file",
  "neogit_status_s_stages_only_stageable_file_rows",
  "session_restore_preserves_requested_cwd",
  "session_options_stay_lightweight",
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
