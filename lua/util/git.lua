local M = {}

local uv = vim.uv or vim.loop

function M.normalize_path(path)
  if not path or path == "" or path:match("^%w[%w+.-]*://") then
    return nil
  end

  return vim.fs.normalize(path)
end

function M.dir_from_buffer(bufnr)
  bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return nil
  end

  local name = M.normalize_path(vim.api.nvim_buf_get_name(bufnr))
  if not name then
    return nil
  end

  local stat = uv.fs_stat(name)
  if stat and stat.type == "directory" then
    return name
  end

  return vim.fs.dirname(name)
end

function M.dir_from_tab_file(tabpage)
  local ok, main_file = pcall(require, "util.main_file")
  if ok then
    local dir = M.dir_from_buffer(main_file.tab_buf(tabpage or 0))
    if dir then
      return dir
    end
  end

  if tabpage == nil or tabpage == 0 or tabpage == vim.api.nvim_get_current_tabpage() then
    return M.dir_from_buffer(0)
  end
end

function M.root_from(dir)
  dir = M.normalize_path(dir)
  if not dir then
    return nil
  end

  local result = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if result.code ~= 0 then
    return nil
  end

  local root = vim.trim(result.stdout)
  if root == "" then
    return nil
  end

  return vim.fs.normalize(root)
end

function M.root_from_tab_file(tabpage)
  return M.root_from(M.dir_from_tab_file(tabpage))
end

return M
