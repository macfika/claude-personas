# Changelog

## 0.3.0

- 菜单栏图标统一使用单色，移除彩色菜单栏设置；配置、启动器及运行副本的颜色保留。
- 手动安装改用 Sparkle 2.10.0，提供自动更新开关、检查更新入口和可见错误提示；迁移旧版明确关闭的偏好。
- 根据当前应用路径、Caskroom 和安装收据识别 Homebrew 管理的副本，仅提供 brew 命令；可疑或损坏收据保守禁用自更新，cask 移除 `auto_updates`。
- `--check-update` 只读；禁用 `--update-now` 直接安装，更新统一经 GUI 或 brew。
- appcast 和旧版 `.zip.sig` 使用相同 Ed25519 seed，为 0.2.x 提供迁移通道。
- 构建支持 `CODESIGN_IDENTITY` 和 `NOTARY_PROFILE`；生产发布要求 Developer ID、stapled 公证及 Gatekeeper 验证通过。支持通过 `archive_release` 从同 tag 草稿导入本机签名公证 ZIP。
- 正式包使用 Developer ID 签名，通过 Apple 公证；旧版 0.2.1 及更早的包仍为 ad-hoc 签名、未公证。
- 发布由同 tag 草稿 ZIP 和必填 `archive_release` 的手动工作流完成；主线 CI 负责构建测试，推 tag 不触发发布。
- 已在隔离 fixture 应用中完成真实 Sparkle 替换与重启；正式包线上升级、0.2.x 迁移、真实账号登录和 Claude 自身更新恢复仍待验收。

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
