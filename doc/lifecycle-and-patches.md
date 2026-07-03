# 生命周期与 Patch 收口

## 生命周期

- `lua/config/lifecycle.lua` 统一管理 `ConfigUiReady`、`ConfigBackground`、`ConfigFilePost`。
- `lua/plugins/mini/project.lua` 统一 recent、session、home 规则。

## Patch

- `lua/patches/blink_preview.lua`
- `lua/patches/noice_signature.lua`
- `lua/patches/bookmarks_tree.lua`
- `lua/patches/overseer_select.lua`

## 备注

- `lua/state/lifecycle.lua` 持有可跨热重载保留的生命周期状态。
