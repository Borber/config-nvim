local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
vim.opt.runtimepath:append(repo)
vim.opt.updatecount = 0

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

local function assert_deep_eq(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(string.format("%s\nexpected: %s\nactual: %s", message, vim.inspect(expected), vim.inspect(actual)), 2)
  end
end

local function reset_modules(...)
  local names = { ... }

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

local function with_clean_state(callback)
  local ok, err = xpcall(callback, debug.traceback)

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == "" then
      pcall(function()
        vim.bo[buf].modified = false
      end)
    end
  end

  if not ok then
    error(err, 0)
  end
end

local tests = {}

function tests.lifecycle_ui_uses_very_lazy_and_replays_once()
  reset_modules("config.lifecycle")
  local lifecycle = require("config.lifecycle")
  local old_ready = vim.g.did_very_lazy
  vim.g.did_very_lazy = false
  local count = 0

  lifecycle.once("ui_ready", function()
    count = count + 1
  end)
  vim.g.did_very_lazy = true
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
  assert_eq(count, 1, "UI subscriber should run only once")

  lifecycle.once("ui_ready", function()
    count = count + 1
  end)
  assert_eq(count, 2, "late UI subscriber should replay immediately")
  vim.g.did_very_lazy = old_ready
end

function tests.lifecycle_file_post_waits_for_ui_and_skips_directories()
  reset_modules("config.lifecycle")
  local lifecycle = require("config.lifecycle")
  lifecycle.setup()
  local received = {}
  lifecycle.once("file_post", function(event)
    received[#received + 1] = event.data.buf
  end)

  local directory = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(directory, vim.fn.getcwd())
  vim.api.nvim_set_current_buf(directory)
  vim.api.nvim_exec_autocmds("UIEnter", { buffer = directory, modeline = false })
  assert_eq(#received, 0, "directory placeholder should not trigger file plugins")

  local special = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(special, vim.fn.tempname())
  vim.api.nvim_set_current_buf(special)
  local uri = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(uri, "zipfile:///tmp/example.zip::file.lua")
  vim.api.nvim_set_current_buf(uri)
  assert_eq(#received, 0, "special buffers and URI paths should not trigger file plugins")

  local file = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(file, vim.fn.tempname() .. ".lua")
  vim.api.nvim_set_current_buf(file)
  assert_eq(received[1], file, "entering a preloaded file should emit file_post")
  vim.api.nvim_exec_autocmds("BufEnter", { buffer = file, modeline = false })
  assert_eq(#received, 1, "file_post should fire only once")

  lifecycle.once("file_post", function(event)
    received[#received + 1] = event.data.buf
  end)
  assert_eq(received[2], file, "late file subscriber should replay the original buffer")
  vim.api.nvim_buf_delete(directory, { force = true })
  vim.api.nvim_buf_delete(special, { force = true })
  vim.api.nvim_buf_delete(uri, { force = true })
  vim.api.nvim_buf_delete(file, { force = true })
end

function tests.lifecycle_scheduled_subscriptions_run_once()
  reset_modules("config.lifecycle")
  local lifecycle = require("config.lifecycle")
  local old_ready = vim.g.did_very_lazy
  vim.g.did_very_lazy = false
  local count = 0
  local function subscribe()
    lifecycle.once("ui_ready", function()
      count = count + 1
    end, { schedule = true })
  end

  subscribe()
  vim.g.did_very_lazy = true
  vim.api.nvim_exec_autocmds("User", { pattern = "VeryLazy", modeline = false })
  assert_eq(count, 0, "scheduled subscriber should wait for the next loop")
  assert_true(
    vim.wait(1000, function()
      return count == 1
    end),
    "scheduled subscriber should run"
  )
  subscribe()
  assert_eq(count, 1, "late scheduled subscriber should also wait for the next loop")
  assert_true(
    vim.wait(1000, function()
      return count == 2
    end),
    "late scheduled subscriber should replay once"
  )
  vim.g.did_very_lazy = old_ready
end

function tests.lifecycle_file_post_handles_file_opened_before_ui()
  reset_modules("config.lifecycle")
  local lifecycle = require("config.lifecycle")
  lifecycle.setup()
  local received
  lifecycle.once("file_post", function(event)
    received = event.data.buf
  end)

  local file = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(file, vim.fn.tempname() .. ".lua")
  vim.api.nvim_set_current_buf(file)
  vim.api.nvim_exec_autocmds("BufReadPost", { buffer = file, modeline = false })
  assert_eq(received, nil, "reading a file before UIEnter should keep file plugins deferred")
  vim.api.nvim_exec_autocmds("UIEnter", { buffer = file, modeline = false })
  assert_eq(received, file, "UIEnter should pick up an already opened file")
  vim.api.nvim_buf_delete(file, { force = true })
end

function tests.overseer_select_routes_only_overseer_kinds()
  with_clean_state(function()
    reset_modules("patches.overseer_select")

    local original_select = vim.ui.select
    local fallback_calls = 0
    local routed_calls = 0

    vim.ui.select = function(items, opts, on_choice)
      fallback_calls = fallback_calls + 1
      if on_choice ~= nil then
        on_choice("fallback")
      end
    end

    local patch = require("patches.overseer_select")
    patch.apply(function(items, opts, on_choice)
      routed_calls = routed_calls + 1
      if on_choice ~= nil then
        on_choice("routed")
      end
    end)

    vim.ui.select({}, { kind = "overseerTask" }, function() end)
    vim.ui.select({}, { kind = "regular" }, function() end)

    assert_eq(routed_calls, 1, "overseer select route should intercept overseer kinds")
    assert_eq(fallback_calls, 1, "overseer select route should leave other kinds alone")

    vim.ui.select = original_select
    vim.ui._config_overseer_patched = nil
    vim.ui._config_overseer_original_select = nil
  end)
end

function tests.bookmarks_tree_icons_and_refresh()
  with_clean_state(function()
    reset_modules("patches.bookmarks_tree", "libs.icons", "bookmarks.sign", "bookmarks.tree.operate", "bookmarks.tree.render")

    local sign_calls = 0
    local refresh_calls = 0

    package.loaded["libs.icons"] = {
      tree = {
        expanded = "+",
        collapsed = "-",
      },
    }
    package.loaded["bookmarks.sign"] = {
      safe_refresh_signs = function()
        sign_calls = sign_calls + 1
      end,
    }
    package.loaded["bookmarks.tree.operate"] = {
      refresh = function()
        refresh_calls = refresh_calls + 1
      end,
    }
    package.loaded["bookmarks.tree.render"] = {
      refresh = function()
        refresh_calls = refresh_calls + 10
      end,
    }

    vim.cmd("silent! enew!")
    local buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "▾ Root", "  ▸ Child" })

    local patch = require("patches.bookmarks_tree")
    patch.apply_tree_icons(buf)
    assert_deep_eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "+ Root", "  - Child" }, "bookmarks tree should rewrite expand/collapse glyphs")

    vim.g.bookmark_tree_view_ctx = {
      win = vim.api.nvim_get_current_win(),
      buf = buf,
      lines_ctx = { root_id = 1 },
    }

    patch.refresh_tree()
    assert_eq(sign_calls, 1, "bookmarks tree refresh should refresh signs")
    assert_eq(refresh_calls, 1, "bookmarks tree refresh should call upstream refresh once")

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "▾ Root", "  ▸ Child" })
    patch.apply_render_patch()
    package.loaded["bookmarks.tree.render"].refresh()
    assert_deep_eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "+ Root", "  - Child" }, "bookmarks tree render patch should post-process refresh output")
  end)
end

function tests.ai_commit_is_available_from_neogit_status_and_commit_popup()
  with_clean_state(function()
    reset_modules("plugins.aicommits", "plugins.neogit")

    local old_local_config = package.loaded["config.local"]
    local old_aicommits = package.loaded["aicommits"]
    package.loaded["config.local"] = {
      aicommits = {},
    }

    local aicommits_spec = require("plugins.aicommits")
    local aicommits_opts = aicommits_spec.opts()
    assert_true(aicommits_opts.integrations.neogit.enabled, "aicommits should keep the Neogit refresh integration")
    assert_true(aicommits_opts.integrations.neogit.mappings.enabled, "aicommits should map C in Neogit status")
    assert_eq(aicommits_opts.integrations.neogit.mappings.key, "C", "Neogit status mapping should use C")

    local neogit_spec = require("plugins.neogit")
    local neogit_opts = neogit_spec.opts()
    local popup_builder = {
      groups = {},
    }

    function popup_builder:new_action_group(name)
      table.insert(self.groups, name)
      return self
    end

    function popup_builder:action(key, name, callback)
      self.action_key = key
      self.action_name = name
      self.action_callback = callback
      return self
    end

    neogit_opts.builders.NeogitCommitPopup(popup_builder)
    assert_eq(popup_builder.groups[1], "AI", "Neogit commit popup should include an AI action group")
    assert_eq(popup_builder.action_key, "C", "AI commit popup action should use C")
    assert_eq(popup_builder.action_name, "AI Commit", "AI popup action should be labeled clearly")

    local commit_calls = 0
    package.loaded["aicommits"] = {
      commit = function()
        commit_calls = commit_calls + 1
      end,
    }
    popup_builder.action_callback()
    assert_eq(commit_calls, 1, "AI commit popup action should call aicommits.commit")

    package.loaded["config.local"] = old_local_config
    package.loaded["aicommits"] = old_aicommits
  end)
end

local test_order = {
  "lifecycle_ui_uses_very_lazy_and_replays_once",
  "lifecycle_file_post_waits_for_ui_and_skips_directories",
  "lifecycle_file_post_handles_file_opened_before_ui",
  "lifecycle_scheduled_subscriptions_run_once",
  "overseer_select_routes_only_overseer_kinds",
  "bookmarks_tree_icons_and_refresh",
  "ai_commit_is_available_from_neogit_status_and_commit_popup",
}

for _, name in ipairs(test_order) do
  local ok, err = xpcall(tests[name], debug.traceback)
  if ok then
    print("ok - " .. name)
  else
    error("not ok - " .. name .. "\n" .. err, 0)
  end
end

print("headless lifecycle and patch checks passed")
