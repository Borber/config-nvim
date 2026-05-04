-- ============================================
-- 全局 Org 笔记配置
-- ============================================
-- 默认使用一个独立于项目的全局笔记本；机器相关路径可以在 lua/config/local.lua 覆盖。
local default_root = "~/Dropbox/org"
local default_drawer_width = 48

local function local_org_config()
  local ok, local_config = pcall(require, "config.local")
  if not ok or type(local_config) ~= "table" then
    return {}
  end

  return local_config.orgmode or {}
end

local function notes_config()
  local config = local_org_config()

  return {
    root = config.root or default_root,
    drawer_width = config.drawer_width or default_drawer_width,
  }
end

-- 路径判断统一走归一化结果，避免 Windows 下 / 和 \ 混用时误判笔记归属。
local function normalize_path(path)
  return vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p"))
end

local function notes_root()
  return normalize_path(notes_config().root)
end

local function notes_file(filename)
  return vim.fs.joinpath(notes_root(), filename)
end

local function ensure_notes_root()
  local root = notes_root()
  local mkdir_ok, mkdir_result = pcall(vim.fn.mkdir, root, "p")
  local ok = (mkdir_ok and mkdir_result == 1) or vim.uv.fs_stat(root) ~= nil

  if not ok then
    vim.notify("Failed to create Org notes root: " .. root, vim.log.levels.ERROR)
  end

  return ok
end

local function notes_drawer_width()
  local width = tonumber(notes_config().drawer_width) or default_drawer_width
  return math.max(32, math.floor(width))
end

local function path_in_notes_root(path)
  local root = notes_root():gsub("[/\\]+$", "")
  local normalized = normalize_path(path)

  if vim.fn.has("win32") == 1 then
    root = root:lower()
    normalized = normalized:lower()
  end

  return vim.startswith(normalized, root .. "/") or normalized == root
end

local function is_notes_buffer(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  return name ~= "" and path_in_notes_root(name)
end

-- ============================================
-- 右侧全局笔记抽屉
-- ============================================
-- 抽屉是普通 split，但只承载全局 Org 根目录里的文件，不参与项目本地工作流。
local function notes_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" and is_notes_buffer(vim.api.nvim_win_get_buf(win)) then
      return win
    end
  end
end

local function load_orgmode()
  local ok, lazy = pcall(require, "lazy")
  if ok then
    lazy.load({ plugins = { "orgmode" } })
  end
end

local function focus_notes_window()
  local win = notes_window()
  if win ~= nil then
    vim.api.nvim_set_current_win(win)
    return
  end

  vim.cmd("rightbelow vsplit")
  vim.cmd("wincmd L")
  vim.api.nvim_win_set_width(0, notes_drawer_width())
  vim.wo.winfixwidth = true
end

local function open_notes_file(filename)
  return function()
    if not ensure_notes_root() then
      return
    end

    load_orgmode()
    focus_notes_window()

    vim.cmd("edit " .. vim.fn.fnameescape(notes_file(filename)))
    vim.bo.buflisted = false
    vim.wo.winfixwidth = true
  end
end

local function close_notes_drawer()
  local win = notes_window()
  if win == nil then
    return false
  end

  local ok, err = pcall(vim.api.nvim_win_close, win, false)
  if not ok then
    vim.notify("Failed to close Org notes drawer: " .. tostring(err), vim.log.levels.WARN)
  end

  return ok
end

local function toggle_notes_drawer()
  if close_notes_drawer() then
    return
  end

  open_notes_file("index.org")()
end

-- ============================================
-- Agenda / Capture 入口
-- ============================================
-- 第一层菜单使用自定义浮窗；真正的 agenda/capture 行为仍交给 orgmode 原生命令。
local function run_org_command(command)
  if not ensure_notes_root() then
    return
  end

  load_orgmode()
  vim.cmd("Org " .. command)
end

local function agenda_items()
  return {
    { key = "a", label = "Week / day agenda", command = "agenda a" },
    { key = "t", label = "All TODO entries", command = "agenda t" },
    { key = "m", label = "Query by tags, props, or TODO", command = "agenda m" },
    { key = "M", label = "Query TODOs only", command = "agenda M" },
    { key = "s", label = "Search keywords", command = "agenda s" },
  }
end

local function capture_items()
  return {
    { key = "t", label = "Task", command = "capture t" },
    { key = "n", label = "Note", command = "capture n" },
    { key = "j", label = "Journal", command = "capture j" },
  }
end

-- 选择器只负责挑选 orgmode 子命令；执行后立刻关闭，避免留下额外临时 buffer。
local function picker_lines(heading, items, action_label)
  local lines = { " " .. heading }

  for _, item in ipairs(items) do
    table.insert(lines, string.format(" %s  %s", item.key, item.label))
  end

  table.insert(lines, "")
  table.insert(lines, " Enter / Space  " .. (action_label or "Open"))
  table.insert(lines, " q / Esc        Close")

  return lines
end

local function picker_width(lines)
  local width = 0

  for _, line in ipairs(lines) do
    width = math.max(width, vim.api.nvim_strwidth(line))
  end

  local max_width = math.max(40, vim.o.columns - 8)
  return math.min(math.max(width + 4, 36), max_width)
end

local function highlight_picker(bufnr, lines, item_count)
  local ns = vim.api.nvim_create_namespace("ConfigOrgPicker")

  vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 1, {
    end_col = #lines[1],
    hl_group = "FloatTitle",
  })

  for row = 1, item_count do
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, 1, {
      end_col = 2,
      hl_group = "FloatTitle",
    })
  end

  for row = item_count + 2, #lines - 1 do
    vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
      end_col = #lines[row + 1],
      hl_group = "Comment",
    })
  end
end

local function open_picker(opts)
  if not ensure_notes_root() then
    return
  end

  local float = require("util.float")
  local items = opts.items
  local lines = picker_lines(opts.heading, items, opts.action_label)
  local width = picker_width(lines)
  local height = #lines
  local bufnr = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(bufnr, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = float.border,
    title = float.title(opts.title),
    title_pos = "center",
  })

  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
  vim.api.nvim_set_option_value("swapfile", false, { buf = bufnr })
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
  highlight_picker(bufnr, lines, #items)
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("winhighlight", float.menu_winhighlight(), { win = win })
  vim.api.nvim_win_set_cursor(win, { 2, 0 })

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function select_item(item)
    close()
    vim.schedule(function()
      opts.on_select(item)
    end)
  end

  for index, item in ipairs(items) do
    vim.keymap.set("n", item.key, function()
      select_item(item)
    end, { buffer = bufnr, nowait = true, silent = true, desc = item.label })

    vim.keymap.set("n", tostring(index), function()
      select_item(item)
    end, { buffer = bufnr, nowait = true, silent = true, desc = item.label })
  end

  local function select_current()
    local row = vim.api.nvim_win_get_cursor(win)[1]
    local item = items[row - 1]
    if item then
      select_item(item)
      return
    end

    close()
  end

  vim.keymap.set("n", "<CR>", select_current, { buffer = bufnr, silent = true, desc = "Select Org command" })
  vim.keymap.set("n", "<Space>", select_current, { buffer = bufnr, silent = true, desc = "Select Org command" })

  vim.keymap.set("n", "q", close, { buffer = bufnr, silent = true, desc = "Close Org picker" })
  vim.keymap.set("n", "<Esc>", close, { buffer = bufnr, silent = true, desc = "Close Org picker" })
end

local function open_agenda_picker()
  open_picker({
    title = "Org Agenda",
    heading = "Select agenda view",
    action_label = "Open",
    items = agenda_items(),
    on_select = function(item)
      run_org_command(item.command)
    end,
  })
end

local function open_capture_picker()
  open_picker({
    title = "Org Capture",
    heading = "Select capture template",
    action_label = "Capture",
    items = capture_items(),
    on_select = function(item)
      run_org_command(item.command)
    end,
  })
end

-- 命令在 init 阶段注册，保证 orgmode 插件尚未加载时也能直接调用 :Notes* 入口。
local function create_notes_commands()
  vim.api.nvim_create_user_command("Notes", toggle_notes_drawer, {
    desc = "Toggle global Org notes drawer",
  })

  vim.api.nvim_create_user_command("NotesInbox", open_notes_file("inbox.org"), {
    desc = "Open global Org inbox",
  })

  vim.api.nvim_create_user_command("NotesJournal", open_notes_file("journal.org"), {
    desc = "Open global Org journal",
  })

  vim.api.nvim_create_user_command("NotesAgenda", open_agenda_picker, {
    desc = "Open Org agenda",
  })

  vim.api.nvim_create_user_command("NotesCapture", open_capture_picker, {
    desc = "Open Org capture",
  })
end

-- ============================================
-- Org 窗口行为
-- ============================================
local function apply_org_float_options()
  if vim.api.nvim_win_get_config(0).relative == "" then
    return
  end

  -- orgmode 自己创建浮窗，这里只补齐本配置统一的浮窗高亮和 gutter 外观。
  local float = require("util.float")
  vim.wo.signcolumn = "no"
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.foldcolumn = "0"
  vim.wo.winhighlight = float.float_winhighlight()
end

local function setup_org_window_options()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ConfigOrgWindowOptions", { clear = true }),
    pattern = { "org", "orgagenda" },
    callback = function(event)
      apply_org_float_options()

      if event.match == "org" and is_notes_buffer(event.buf) then
        -- 全局笔记抽屉不进入普通 buffer 列表，避免污染项目工作流。
        vim.bo[event.buf].buflisted = false
      end

      if event.match == "org" then
        vim.wo.conceallevel = 2
        vim.wo.foldlevel = 99
      end
    end,
    desc = "Set Org window options",
  })
end

-- ============================================
-- Org runtime 兼容处理
-- ============================================
local function setup_org_time_locale()
  if vim.fn.has("win32") == 0 then
    return
  end

  -- Org agenda 依赖 Lua 的本地化日期名；Windows 中文 locale 需要显式使用 UTF-8 变体。
  pcall(function()
    vim.cmd("language time zh_CN.utf8")
  end)
end

local function setup_org_parser_compilers()
  local ok, install = pcall(require, "orgmode.utils.treesitter.install")
  if not ok then
    return
  end

  -- Windows 下优先使用显式安装的编译器，避免 tree-sitter parser 构建时找不到 cc。
  install.compilers = { vim.fn.getenv("CC"), "gcc", "clang", "cc", "cl", "zig" }
end

-- ============================================
-- lazy.nvim 插件规格
-- ============================================
return {
  "nvim-orgmode/orgmode",
  ft = { "org" },
  cmd = { "Org" },
  init = function()
    create_notes_commands()
  end,
  keys = {
    { "<leader>nn", toggle_notes_drawer, desc = "Toggle notes" },
    { "<leader>ni", open_notes_file("inbox.org"), desc = "Notes inbox" },
    { "<leader>nj", open_notes_file("journal.org"), desc = "Notes journal" },
    { "<leader>na", open_agenda_picker, desc = "Notes agenda" },
    { "<leader>nc", open_capture_picker, desc = "Notes capture" },
  },
  opts = function()
    local root = notes_root()
    local float = require("util.float")

    return {
      -- agenda/capture 始终指向全局笔记本，不跟随当前项目 cwd。
      org_agenda_files = { root .. "/**/*.org" },
      org_default_notes_file = notes_file("inbox.org"),
      org_capture_templates = {
        t = {
          description = "Task",
          template = "* TODO %?\n  %u",
          target = notes_file("inbox.org"),
        },
        n = {
          description = "Note",
          template = "* %?\n  %u",
          target = notes_file("inbox.org"),
        },
        j = {
          description = "Journal",
          template = "* %U %?",
          target = notes_file("journal.org"),
          datetree = true,
        },
      },
      ui = {
        input = {
          -- 让 orgmode 内部输入走 vim.ui.input，再交给 Noice 的 cmdline_input 浮窗。
          use_vim_ui = true,
        },
      },
      -- orgmode 原生 agenda/capture 窗口统一使用浮窗，并复用当前配置的边框。
      win_split_mode = { "float", 0.82 },
      win_border = float.borderchars("FloatBorder"),
      mappings = {
        global = {
          -- 全局入口由 <leader>n* 和 :Notes* 接管，避免 orgmode 默认键位散落到全局。
          org_agenda = false,
          org_capture = false,
        },
      },
    }
  end,
  config = function(_, opts)
    setup_org_parser_compilers()
    setup_org_time_locale()
    require("orgmode").setup(opts)
    setup_org_window_options()
  end,
}
