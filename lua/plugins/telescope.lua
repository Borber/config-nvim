local function buffer_path_display(_, path)
  local filename = vim.fn.fnamemodify(path, ":t")
  local parent = vim.fn.fnamemodify(vim.fn.fnamemodify(path, ":h"), ":~:.")

  if parent == "." or parent == "" then
    return filename
  end

  -- Buffer 列表优先显示文件名，只保留一段短目录用来区分同名文件。
  return filename .. " " .. parent:gsub("\\", "/")
end

return {
  "nvim-telescope/telescope.nvim",
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
      function()
        require("telescope.builtin").live_grep()
      end,
      desc = "Live grep",
    },
    {
      "<leader>,",
      function()
        require("telescope.builtin").buffers({
          path_display = buffer_path_display,
        })
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
