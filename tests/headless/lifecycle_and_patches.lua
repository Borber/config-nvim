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

function tests.lifecycle_once_runs_immediately_after_ready()
  with_clean_state(function()
    reset_modules("config.lifecycle", "state.lifecycle")

    local lifecycle = require("config.lifecycle")
    lifecycle.setup()
    lifecycle.emit("ui_ready")
    local count = 0

    lifecycle.once("ui_ready", function()
      count = count + 1
    end)

    assert_eq(count, 1, "lifecycle.once should fire immediately after ui_ready")
  end)
end

function tests.lifecycle_on_handles_multiple_emissions()
  with_clean_state(function()
    reset_modules("config.lifecycle", "state.lifecycle")

    local lifecycle = require("config.lifecycle")
    lifecycle.setup()
    local count = 0

    lifecycle.on("file_post", function()
      count = count + 1
    end)

    lifecycle.emit("file_post", { buf = 0 })
    lifecycle.emit("file_post", { buf = 0 })

    assert_eq(count, 2, "lifecycle.on should remain active across repeated file_post emissions")
  end)
end

function tests.blink_preview_expands_snippets_and_restores_cursor()
  with_clean_state(function()
    reset_modules("patches.blink_preview", "blink.cmp.lib.text_edits", "blink.cmp.sources.snippets.utils")

    local applied_text
    package.loaded["blink.cmp.lib.text_edits"] = {
      get_from_item = function(item)
        return { newText = item.newText }
      end,
      get_undo_text_edit = function(edit)
        return { undo = edit.newText }
      end,
      apply = function(edit)
        applied_text = edit.newText
      end,
    }
    package.loaded["blink.cmp.sources.snippets.utils"] = {
      safe_parse = function()
        return setmetatable({}, {
          __tostring = function()
            return "expanded"
          end,
        })
      end,
    }

    vim.cmd("silent! enew!")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha" })
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local patch = require("patches.blink_preview")
    local undo = patch.preview_multiline_completion({
      insertTextFormat = vim.lsp.protocol.InsertTextFormat.Snippet,
      newText = "${1:hello}",
    })

    assert_eq(applied_text, "expanded", "blink preview should expand snippet text before previewing")
    assert_eq(undo.undo, "expanded", "blink preview should return an undo edit for the expanded text")
    assert_eq(vim.api.nvim_win_get_cursor(0)[1], 1, "blink preview should restore the original cursor row")
    assert_eq(vim.api.nvim_win_get_cursor(0)[2], 0, "blink preview should restore the original cursor column")
  end)
end

function tests.noice_signature_guard_blocks_while_menu_visible()
  with_clean_state(function()
    reset_modules("patches.noice_signature", "noice.lsp.signature", "blink.cmp")

    local check_calls = 0
    local on_signature_calls = 0
    local menu_visible = false

    package.loaded["noice.lsp.signature"] = {
      check = function()
        check_calls = check_calls + 1
      end,
      on_signature = function()
        on_signature_calls = on_signature_calls + 1
      end,
    }
    package.loaded["blink.cmp"] = {
      is_menu_visible = function()
        return menu_visible
      end,
    }

    local patch = require("patches.noice_signature")
    patch.apply()
    patch.apply()

    local signature = package.loaded["noice.lsp.signature"]
    signature.check()
    signature.on_signature()
    assert_eq(check_calls, 1, "signature helper should pass through while menu is hidden")
    assert_eq(on_signature_calls, 1, "signature helper should pass through while menu is hidden")

    menu_visible = true
    signature.check()
    signature.on_signature()
    assert_eq(check_calls, 1, "signature helper should block while blink menu is visible")
    assert_eq(on_signature_calls, 1, "signature helper should block while blink menu is visible")
    assert_true(rawget(signature, "_config_nvim_blink_guarded") == true, "noice signature guard should be marked as applied")
  end)
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
  "lifecycle_once_runs_immediately_after_ready",
  "lifecycle_on_handles_multiple_emissions",
  "blink_preview_expands_snippets_and_restores_cursor",
  "noice_signature_guard_blocks_while_menu_visible",
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
