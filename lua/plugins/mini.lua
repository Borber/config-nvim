return {
  "nvim-mini/mini.nvim",
  lazy = false,
  priority = 900,
  config = function()
    -- 图标：作为 nvim-web-devicons 的替代，其它插件通过 mock 自动复用
    require("mini.icons").setup()
    MiniIcons.mock_nvim_web_devicons()

    require("mini.pairs").setup()
    require("mini.ai").setup()
    -- 常用编辑增强：注释、移动选区/行、交互式对齐，以及参数 split/join。
    require("mini.comment").setup()
    require("mini.move").setup()
    require("mini.align").setup()
    require("mini.splitjoin").setup()
    require("mini.bufremove").setup()
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

    require("plugins.mini.visits").setup()
    require("plugins.mini.files").setup()

    local sessions = require("plugins.mini.sessions")
    sessions.setup()

    vim.keymap.set("n", "<leader>e", function()
      require("plugins.mini.files").toggle()
    end, {
      desc = "Explorer",
      silent = true,
    })

    -- mini.bufremove 删除 buffer 时尽量保留窗口布局，比 :bd 更适合 buffer-first 工作流。
    vim.keymap.set("n", "<leader>bd", function()
      require("mini.bufremove").delete(0, false)
    end, {
      desc = "Delete buffer",
      silent = true,
    })

    vim.keymap.set("n", "<leader>bD", function()
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
