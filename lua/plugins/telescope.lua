local function normalize_display_path(path)
  return vim.fs.normalize(path):gsub("\\", "/")
end

local is_windows = package.config:sub(1, 1) == "\\"

local function normalize_buffer_path(path)
  if not is_windows or not path:match("^%a:[/\\]") then
    return path
  end

  return vim.fs.normalize(path):gsub("/", "\\")
end

local function cwd_relative_path(path)
  if path == nil or path == "" then
    return path
  end

  if not path:find("[/\\]") and not path:match("^%a:") then
    return path
  end

  local normalized = normalize_display_path(path)
  if not normalized:match("^/") and not normalized:match("^%a:/") then
    return normalized
  end

  local relative = vim.fs.relpath(normalize_display_path(vim.uv.cwd() or vim.fn.getcwd()), normalized)
  if relative ~= nil then
    return relative
  end

  return normalize_display_path(vim.fn.fnamemodify(normalized, ":~"))
end

local function buffer_path_display(_, path)
  local display_path = cwd_relative_path(path)
  local filename = vim.fn.fnamemodify(display_path, ":t")
  local parent = vim.fn.fnamemodify(display_path, ":h")

  if parent == "." or parent == "" then
    return filename
  end

  -- Windows 下 Telescope 可能先传入未相对化的绝对路径，这里保持 buffer 列表文件名优先。
  return filename .. " " .. normalize_display_path(parent)
end

local function buffer_number_width()
  local max_bufnr = 1

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.fn.buflisted(bufnr) == 1 then
      max_bufnr = math.max(max_bufnr, bufnr)
    end
  end

  return #tostring(max_bufnr)
end

local function buffer_entry_maker(opts)
  local make_default_entry

  return function(entry)
    if make_default_entry == nil then
      make_default_entry = require("telescope.make_entry").gen_from_buffer(opts)
    end

    if entry.info == nil or entry.info.name == "" then
      return make_default_entry(entry)
    end

    return make_default_entry(vim.tbl_extend("force", entry, {
      info = vim.tbl_extend("force", entry.info, {
        name = normalize_buffer_path(entry.info.name),
      }),
    }))
  end
end

local function selected_text()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_row, start_col = start_pos[2], start_pos[3]
  local end_row, end_col = end_pos[2], end_pos[3]

  if start_row == 0 or end_row == 0 then
    return nil
  end

  if start_row > end_row or (start_row == end_row and start_col > end_col) then
    start_row, end_row = end_row, start_row
    start_col, end_col = end_col, start_col
  end

  local lines = vim.api.nvim_buf_get_text(0, start_row - 1, start_col - 1, end_row - 1, end_col, {})
  local text = table.concat(lines, "\n")

  return text ~= "" and text or nil
end

local function live_grep(opts)
  return function()
    require("telescope.builtin").live_grep(opts)
  end
end

local function live_grep_current_text()
  return function()
    require("telescope.builtin").live_grep({
      default_text = selected_text() or vim.fn.expand("<cword>"),
    })
  end
end

return {
  "nvim-telescope/telescope.nvim",
  cmd = "Telescope",
  keys = {
    {
      "<leader>/",
      function()
        require("telescope.builtin").current_buffer_fuzzy_find()
      end,
      desc = "Search buffer",
    },
    {
      "<leader>ff",
      function()
        require("telescope.builtin").find_files()
      end,
      desc = "Find files",
    },
    {
      "<leader>fg",
      live_grep(),
      desc = "Live grep",
    },
    {
      "<leader>fw",
      live_grep_current_text(),
      desc = "Search word",
      mode = { "n", "x" },
    },
    {
      "<leader>,",
      function()
        local opts = {
          bufnr_width = buffer_number_width(),
          path_display = buffer_path_display,
        }
        opts.entry_maker = buffer_entry_maker(opts)

        require("telescope.builtin").buffers(opts)
      end,
      desc = "Buffers",
    },
    {
      "<leader>fh",
      function()
        require("telescope.builtin").help_tags()
      end,
      desc = "Help tags",
    },
    {
      "<leader>fr",
      function()
        require("telescope.builtin").oldfiles()
      end,
      desc = "Recent files",
    },
    {
      "<leader>fH",
      function()
        require("telescope.builtin").command_history(require("telescope.themes").get_dropdown({
          -- previewer = false,
          borderchars = require("util.float").telescope_dropdown_borderchars(),
          layout_config = {
            width = 0.4,
            height = 0.45,
          },
        }))
      end,
      desc = "Command history",
    },
  },
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      -- fzf-native 是 C 扩展，需要本地编译；加载失败时直接暴露工具链问题。
      build = "cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release --target install",
    },
  },
  config = function()
    local actions = require("telescope.actions")
    local float = require("util.float")
    local telescope = require("telescope")

    telescope.setup({
      defaults = vim.tbl_deep_extend("force", float.telescope_defaults(), {
        mappings = {
          i = {
            ["<Esc>"] = actions.close,
            -- Telescope prompt 有自己的 buffer-local 映射，显式保留全局习惯里的 Alt 上下移动。
            ["<M-j>"] = actions.move_selection_next,
            ["<M-k>"] = actions.move_selection_previous,
          },
          n = {
            ["<Esc>"] = actions.close,
            ["<M-j>"] = actions.move_selection_next,
            ["<M-k>"] = actions.move_selection_previous,
          },
        },
      }),
      extensions = {
        fzf = {
          -- 用 fzf-native 替换默认排序器，文件和文本搜索都会更快。
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
      },
    })

    telescope.load_extension("fzf")
    float.apply_highlights()
  end,
}
