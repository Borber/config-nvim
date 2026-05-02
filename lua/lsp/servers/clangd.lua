-- C/C++ 只启用通用 clangd 能力，不写项目路径或 Chromium 专用探测。
return {
  cmd = {
    "clangd",
    "--background-index", -- 后台索引，提升跨文件跳转和引用查找体验
    "--completion-style=detailed", -- 补全项保留更多类型/签名信息
    "--header-insertion=never", -- 不让 clangd 自动插入 include，避免误改代码
  },
  init_options = {
    clangdFileStatus = true, -- 允许 clangd 回报索引/解析状态
  },
}
