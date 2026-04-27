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

    vim.api.nvim_create_user_command("Starter", function()
      require("plugins.mini.starter").open()
    end, { desc = "Open starter", force = true })

    if vim.fn.argc() == 0 and not sessions.has_current() then
      require("plugins.mini.starter").setup({ autoopen = true })
    end
  end,
}
