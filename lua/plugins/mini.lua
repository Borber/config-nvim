return {
  "nvim-mini/mini.nvim",
  lazy = false,
  priority = 900,
  config = function()
    local editing_configured = false
    local icons_configured = false

    local function setup_icons()
      if icons_configured then
        return
      end

      icons_configured = true

      -- 图标：作为 nvim-web-devicons 的替代；延迟到 VeryLazy，避免 starter 首屏加载图标系统。
      require("mini.icons").setup()
      MiniIcons.mock_nvim_web_devicons()
    end

    local function setup_editing_modules()
      if editing_configured then
        return
      end

      editing_configured = true

      require("mini.pairs").setup()
      require("mini.ai").setup()
      require("mini.move").setup()
      require("mini.align").setup()
      require("mini.splitjoin").setup()
      require("plugins.mini.trailspace").setup()

      require("mini.surround").setup({
        mappings = {
          add = "msa",
          delete = "msd",
          find = "msf",
          find_left = "msF",
          highlight = "msh",
          replace = "msr",
        },
      })
    end

    local function setup_editing_autocmds()
      local group = vim.api.nvim_create_augroup("ConfigMiniEditing", { clear = true })

      -- Starter 首屏不需要编辑增强；进入真实文件或开始输入时再启用，保留日常编辑手感。
      vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "ConfigFilePost",
        callback = setup_editing_modules,
        desc = "Load editing mini modules after first real file",
      })

      vim.api.nvim_create_autocmd("InsertEnter", {
        group = group,
        once = true,
        callback = setup_editing_modules,
        desc = "Load editing mini modules before inserting text",
      })
    end

    local function setup_very_lazy_modules()
      setup_icons()
      require("plugins.mini.visits").setup()
    end

    vim.api.nvim_create_autocmd("User", {
      group = vim.api.nvim_create_augroup("ConfigMiniVeryLazy", { clear = true }),
      pattern = "VeryLazy",
      callback = setup_very_lazy_modules,
      desc = "Load nonessential mini startup helpers",
    })

    if vim.g.did_very_lazy then
      setup_very_lazy_modules()
    end

    setup_editing_autocmds()

    local sessions = require("plugins.mini.sessions")
    sessions.setup()

    vim.keymap.set("n", "<leader>e", function()
      require("plugins.mini.files").toggle()
    end, {
      desc = "Explorer",
      silent = true,
    })

    -- mini.bufremove 删除 buffer 时尽量保留窗口布局，比 :bd 更适合 buffer-first 工作流。
    vim.keymap.set("n", "<leader>x", function()
      require("mini.bufremove").delete(0, false)
    end, {
      desc = "Delete buffer",
      silent = true,
    })

    vim.keymap.set("n", "<leader>X", function()
      require("mini.bufremove").delete(0, true)
    end, {
      desc = "Force delete buffer",
      silent = true,
    })

    vim.api.nvim_create_user_command("Starter", function()
      require("plugins.mini.starter").open()
    end, { desc = "Open starter", force = true })

    if vim.fn.argc() == 0 and not sessions.has_current() then
      require("plugins.mini.starter").setup({ autoopen = true })
    end
  end,
}
