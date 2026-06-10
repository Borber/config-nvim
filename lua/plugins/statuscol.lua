return {
  "luukvbaal/statuscol.nvim",
  event = { "BufReadPost", "BufNewFile" },
  opts = function()
    local builtin = require("statuscol.builtin")

    return {
      segments = {
        { text = { "%C" }, click = "v:lua.ScFa" },
        {
          sign = { name = { ".*" }, text = { ".*" }, namespace = { ".*" }, maxwidth = 1, colwidth = 1, auto = " " },
          click = "v:lua.ScSa",
        },
        { text = { builtin.lnumfunc }, click = "v:lua.ScLa" },
        {
          sign = { namespace = { "gitsigns.*" }, maxwidth = 1, colwidth = 1, auto = " ", wrap = true },
          click = "v:lua.ScSa",
        },
      },
    }
  end,
}
