return {
  settings = {
    ["rust-analyzer"] = {
      -- Rust 项目默认启用所有 feature，避免条件编译下的符号缺失。
      cargo = { allFeatures = true },
    },
  },
}
