local function git(args)
  return function()
    if args == nil or args == "" then
      vim.cmd.Git()
      return
    end

    vim.cmd("Git " .. args)
  end
end

return {
  "tpope/vim-fugitive",
  cmd = {
    "G",
    "Git",
    "GDelete",
    "GMove",
    "GRename",
    "Gclog",
    "Gdiffsplit",
    "Gedit",
    "Ggrep",
    "Gllog",
    "Gread",
    "Gsplit",
    "Gtabedit",
    "Gvdiffsplit",
    "Gwrite",
  },
  keys = {
    { "<leader>gg", git(), desc = "Git status" },
    { "<leader>gc", git("commit"), desc = "Git commit" },
    { "<leader>gl", git("log --oneline --decorate --graph --all"), desc = "Git log" },
  },
}
