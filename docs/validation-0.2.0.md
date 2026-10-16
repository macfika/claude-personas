# 0.2.0 多语言验证记录

日期：2026-10-16（日本时间）。

- Swift Package 构建及通用 arm64 / x86_64 app 构建通过。
- 完整自测共 153 项通过，其中新增 60 项语言检查：系统语言优先级、简繁脚本与地区、英语回退、手动选择与持久化、切回系统、资源覆盖及参数保留。
- 五种语言各 108 个界面 key，全部对应；10 个 `.strings` 文件通过格式检查。
- 演示界面确认默认系统简体中文，并实际切换日语、繁体中文、韩语及英语，菜单、设置和辅助功能标签同步刷新。日语面板截图检查换行和窗口布局正常。
- [GitHub CI](https://github.com/macfika/claude-personas/actions/runs/38870150823) 与 [Release](https://github.com/macfika/claude-personas/actions/runs/38870294875) 通过。
- 下载正式 `ClaudePersonas-0.2.0.zip`，Ed25519 验签及深度代码签名检查通过；从解压的正式 app 再运行 60 项本地化检查通过。
- Homebrew cask 已自动更新至 0.2.0；`brew fetch --cask macfika/claude-personas/claude-personas` 下载与 SHA-256 校验通过。

正式 ZIP SHA-256：

```text
5f370d887887b74edf162deeaba5709f9dbf78c9aab140dd543b7e580545bf30
```

语言选择的持久化由隔离偏好域自测覆盖。真实账号登录、SSO、Claude 实际升级恢复的验收范围沿用 [功能对照表](feature-parity.md)，本次未重新操作真实账号。
