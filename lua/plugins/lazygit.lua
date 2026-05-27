local terminals = {}

local function default_lazygit_cwd()
  return require("libs.git").root_from_buffer_or_cwd(0)
end

local function command(args)
  local parts = { "lazygit" }

  for _, arg in ipairs(args or {}) do
    table.insert(parts, vim.fn.shellescape(arg))
  end

  return table.concat(parts, " ")
end

local function display_name(cwd, args)
  local name = "LazyGit"
  if args and #args > 0 then
    name = name .. " " .. table.concat(args, " ")
  end

  return string.format("%s (%s)", name, vim.fs.basename(cwd))
end

local function terminal_key(cwd, args)
  return cwd .. "\0" .. command(args)
end

local function open_lazygit(args)
  return function()
    if vim.fn.executable("lazygit") ~= 1 then
      vim.notify("lazygit not found in PATH", vim.log.levels.ERROR)
      return
    end

    local cwd = default_lazygit_cwd()
    local key = terminal_key(cwd, args)
    local terminal = terminals[key]

    if terminal == nil then
      local float = require("util.float")
      local Terminal = require("toggleterm.terminal").Terminal
      terminal = Terminal:new({
        cmd = command(args),
        dir = cwd,
        direction = "float",
        display_name = display_name(cwd, args),
        hidden = true,
        close_on_exit = true,
        float_opts = {
          border = float.border,
          width = function()
            return math.floor(vim.o.columns * 0.92)
          end,
          height = function()
            return math.floor(vim.o.lines * 0.86)
          end,
        },
        on_open = function()
          vim.cmd("startinsert")
        end,
      })
      terminals[key] = terminal
    end

    terminal:toggle()
  end
end

local function create_lazygit_command()
  vim.api.nvim_create_user_command("LazyGit", function(command_opts)
    open_lazygit(command_opts.fargs)()
  end, {
    nargs = "*",
    desc = "Open LazyGit",
    force = true,
  })
end

local spec = {
  "akinsho/toggleterm.nvim",
  init = create_lazygit_command,
  keys = {
    { "<leader>gg", open_lazygit(), desc = "LazyGit" },
    { "<leader>gl", open_lazygit({ "log" }), desc = "Git log" },
  },
}

spec.open = open_lazygit
spec.default_cwd = default_lazygit_cwd

return spec
