local M = {}

local uv = vim.uv or vim.loop

local function normalize_path(path)
  if path == nil or path == "" then
    return nil
  end

  return vim.fn.fnamemodify(path, ":p")
end

local function is_directory(path)
  return path ~= nil and vim.fn.isdirectory(path) == 1
end

local function format_path_name(path)
  local name = vim.fn.fnamemodify(path, ":t")

  if name == "" or name == "." then
    name = vim.fn.fnamemodify(path, ":~")
  end

  if is_directory(path) then
    name = name .. " [dir]"
  end

  return string.format("%s (%s)", name, vim.fn.fnamemodify(path, ":~:."))
end

function M.setup()
  require("mini.visits").setup()
end

function M.register_directory(path)
  local directory = normalize_path(path)
  if not is_directory(directory) then
    return
  end

  require("mini.visits").register_visit(directory, vim.fn.getcwd())
end

function M.open_path(path)
  local resolved_path = normalize_path(path)
  if resolved_path == nil then
    return
  end

  vim.cmd("edit " .. vim.fn.fnameescape(resolved_path))
end

function M.recent_paths_section(limit)
  limit = limit or 5

  return function()
    local visits = require("mini.visits")
    local paths = visits.list_paths("", {
      sort = visits.gen_sort.default({ recency_weight = 1 }),
      filter = function(path_data)
        return uv.fs_stat(path_data.path) ~= nil
      end,
    })

    local items = {}
    for _, path in ipairs(paths) do
      table.insert(items, {
        action = function()
          M.open_path(path)
        end,
        name = format_path_name(path),
        section = "Recent paths",
      })

      if #items >= limit then
        break
      end
    end

    if #items == 0 then
      return {
        {
          name = "There are no recent paths yet",
          action = "",
          section = "Recent paths",
        },
      }
    end

    return items
  end
end

return M