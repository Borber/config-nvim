return {
  -- 服务器接收缺省配置时会关闭校验，显式保留 JSON/JSONC 诊断。
  settings = {
    json = {
      validate = { enable = true },
    },
  },
}
