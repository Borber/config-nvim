return {
  "Borber/vim-wakatime",
  event = { "BufWritePost" },
  opts = {
    status_bar_enabled = false,
    -- Wakapi 2.17.x 只识别 *-wakatime 插件名；等服务端升级后可去掉这个兼容项。
    plugin_name = "vim-wakatime",
    sync_ai_disabled = true
  },
}
