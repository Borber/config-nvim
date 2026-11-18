return {
  -- Glancer 只在初始化时读取配置；显式保留编译诊断，避免切换后静默丢失错误提示。
  init_options = {
    diagnostics = {
      onStartup = true,
      onSave = true,
      command = "check",
    },
  },
}
