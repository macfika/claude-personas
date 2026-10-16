# Changelog

## 0.2.1

- 修复语言设置行的对齐：图标、标题、间距和悬停背景与其他设置项一致，语言选择器靠右显示。

## 0.2.0

- 支持简体中文、繁体中文、日语、韩语和英语，默认按系统语言显示。
- 设置中增加语言菜单，手动选择即时生效并持久保存，可随时恢复跟随系统。
- 本地化菜单、弹窗、状态通知、辅助功能、关于窗口和系统权限说明；用户配置名称和数据路径保持原样。
- 增加系统语言匹配、简繁地区回退、偏好持久化和五语言资源覆盖检查。

## 0.1.0

Claude Personas 首个版本，基于 MultiClaude 提交 `dfb986a16b02b07d0b45d07fbed89a18ab52e396`（Apache 2.0）适配。

- 保留多账号配置、独立数据目录、菜单栏管理、状态与前台识别。
- 保留每配置启动器、颜色图标、Dock 集成、Claude Code 配置、MCP 复制及配置复制。
- 保留登录路由、快捷键、登录时启动，以及 Claude 更新后的配置恢复逻辑。
- 拆分 Swift 源文件，使用 `ClaudePersonas.app` / `com.macfika.claude-personas` 的独立标识。
- 提供 universal 构建、同仓库 Homebrew cask、GitHub Releases 流程和独立 Ed25519 更新签名。
- 默认只构建，安装需要 `--install`；包含本项目更新公钥的构建默认开启自动更新。

构建使用 ad-hoc 代码签名，尚未使用 Developer ID 签名或 Apple 公证。真实双账号登录、Google/SSO 回调、Claude 更新恢复和应用自更新替换重启尚未完成端到端验证，详见 `docs/feature-parity.md`。
