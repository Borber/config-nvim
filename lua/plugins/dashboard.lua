local scroll_keys = {
  "<ScrollWheelUp>",
  "<ScrollWheelDown>",
  "<ScrollWheelLeft>",
  "<ScrollWheelRight>",
  "<S-ScrollWheelUp>",
  "<S-ScrollWheelDown>",
  "<S-ScrollWheelLeft>",
  "<S-ScrollWheelRight>",
}


return {
  "nvim-mini/mini.nvim",
  init = function()
    local dashboard_group = vim.api.nvim_create_augroup("mini_starter_ui", { clear = true })

    local function is_starter(buf)
      return vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "ministarter"
    end

    local function apply_starter_window(buf)
      if not is_starter(buf) then
        return
      end

      if vim.g.ministarter_laststatus == nil then
        vim.g.ministarter_laststatus = vim.o.laststatus
      end
      if vim.g.ministarter_ruler == nil then
        vim.g.ministarter_ruler = vim.o.ruler
      end

      vim.o.laststatus = 0
      vim.o.ruler = false

      local opts = { buffer = buf, silent = true, nowait = true }
      for _, key in ipairs(scroll_keys) do
        vim.keymap.set("n", key, "<Nop>", opts)
      end
    end

    local function restore_starter_window()
      if vim.g.ministarter_laststatus ~= nil then
        vim.o.laststatus = vim.g.ministarter_laststatus
        vim.g.ministarter_laststatus = nil
      end
      if vim.g.ministarter_ruler ~= nil then
        vim.o.ruler = vim.g.ministarter_ruler
        vim.g.ministarter_ruler = nil
      end
    end

    vim.api.nvim_create_autocmd("User", {
      group = dashboard_group,
      pattern = "MiniStarterOpened",
      callback = function()
        apply_starter_window(vim.api.nvim_get_current_buf())
      end,
    })

    vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
      group = dashboard_group,
      callback = function(event)
        if is_starter(event.buf) then
          apply_starter_window(event.buf)
          return
        end

        restore_starter_window()
      end,
    })
  end,
  config = function()
    local starter = require("mini.starter")

    require("mini.pick").setup()
    require("mini.files").setup({
      options = {
        use_as_default_explorer = true,
      },
    })

    starter.setup({
      header = "",
      footer = "",
      items = {
        {
          name = "Find file",
          action = function()
            require("mini.pick").builtin.files()
          end,
          section = "Actions",
        },
        {
          name = "New file",
          action = "ene | startinsert",
          section = "Actions",
        },
        {
          name = "Open folder",
          action = function()
            local dir = vim.fn.input("Open folder: ", vim.fn.getcwd(), "dir")
            if dir == "" or vim.fn.isdirectory(dir) == 0 then
              return
            end

            vim.cmd("edit " .. vim.fn.fnameescape(dir))
          end,
          section = "Actions",
        },
        {
          name = "New tab",
          action = "tabnew",
          section = "Actions",
        },
        {
          name = "Config",
          action = function()
            vim.cmd("edit " .. vim.fn.fnameescape(vim.fn.stdpath("config")))
          end,
          section = "Actions",
        },
        {
          name = "Quit",
          action = "qa",
          section = "Actions",
        },
        starter.sections.recent_files(5, false, true),
      },
      content_hooks = {
        starter.gen_hook.aligning("center", "center"),
      },
      silent = true,
    })
  end,
}
