# Claude Personas

- [x] 对照上游功能并记录源码来源、许可和差异。
- [x] 适配 SwiftUI 应用，拆分源文件，隔离身份、数据和更新信任。
- [x] 配置通用二进制构建、测试、GitHub Release 和 Homebrew cask。
- [x] 编译并运行核心自测，验证打包与安装路径。
- [x] 发布到 macfika/claude-personas，验证 Homebrew 安装。

## Review

本机 Swift 6.4 严格并发编译，arm64/x86_64 通用应用，93 项自测断言通过；codesign 和 Info.plist 检查通过。
演示模式下已检查面板布局、创建配置及点击启动的状态更新。真实账号登录、SSO、Claude 自动升级恢复未验收。
GitHub CI 和 v0.1.0 Release 成功；正式包 Homebrew 安装/卸载、签名更新到临时副本均已验证。
详细证据与人工验收边界见 docs/validation.md。

## 多语言（0.2.0）

- [x] 增加跟随系统和手动五语言切换、持久化选择与即时刷新。
- [x] 本地化菜单、设置、右键菜单、弹窗、辅助功能及状态通知。
- [x] 将五语言资源打包到 app 与 Swift Package，验证语言回退和翻译覆盖。
- [x] 编译、自测与演示切换验证，发布新版并更新 Homebrew。

0.2.0：153 项完整自测通过，五语言各 108 项文案覆盖；默认系统简体中文及四种其他语言的界面即时切换已验证。
CI、Release、正式包本地化自测、Ed25519 验签、代码签名及 Homebrew 下载校验通过。见 docs/validation-0.2.0.md。

## 语言行对齐（0.2.1）

- [x] 对照现有设置行修正图标、标题、左右间距与悬停布局。
- [x] 编译和实际界面检查，确认语言选择功能保持正常。
- [x] 发布修复版本并更新 Homebrew。

0.2.1：中文和日语演示截图确认语言行图标、标题与相邻设置对齐，选择器右对齐且切换正常；本地及 CI 的 153 项自测通过，Release 成功。

## 更新通道与菜单清理（0.3.0）

- [x] 删除彩色菜单栏图标设置及相关行为。
- [x] 使用安装收据/实际应用路径识别 Homebrew 安装，阻止其自更新并提供 brew 升级指引。
- [x] 手动安装集成 Sparkle、检查更新入口和可见错误，移除旧自动替换机制。
- [x] 实现 appcast 生成、旧签名兼容、Developer ID/公证构建和发布门禁。
- [x] 发布正式 0.3.0 与 appcast，验证临时旧版线上迁移和 Homebrew 下载/版本发现。
- [x] 构建、自测、界面检查并更新文档、Homebrew 管理策略。

### 0.3.0 Review

172 项自测、SwiftPM 编译、universal 主程序与 Sparkle framework、Developer ID/hardened runtime 签名验证通过。
19 个临时安装来源案例通过，真实 /Applications 副本只读检测为 Homebrew。
实际 Sparkle fixture 更新通过：旧 PID 83079/v1 退出，原安装路径替换并由新 PID 83159/v2 启动；更新后 codesign 校验通过。
隔离演示 UI 已检查中文设置行对齐、彩色菜单栏设置移除；未操作真实 Claude 账号。
发布流程已加入 tag/包版本匹配、对真实发布包自测及 Developer ID/stapler/Gatekeeper 门禁。
Apple 公证 Accepted，已 staple，最终 ZIP 解压票据验证通过；Release 39129187650 成功，线上两种签名/appcast/校验和通过；真实 0.2.1 临时 CLI 副本迁移成功，brew fetch 和默认 outdated 发现 0.3.0 均通过，保留真实运行应用。详细证据见 docs/validation-0.3.0.md。

## 图形化手动安装包

- [x] 提供签名公证的图形化 DMG，明确显示拖入 Applications 的安装步骤。
- [x] 将 DMG 纳入后续构建/CI/发布校验，保留 ZIP 供 Sparkle 和 Homebrew。
- [x] 核实卸载 brew 后设置保留和手动更新通道，更新迁移说明。
- [x] 发布当前版本 DMG 并验证下载、签名、公证与内容。

### 图形安装 Review

0.3.0 的 DMG 已签名、公证、staple，并补充到现有正式 Release；公开下载 SHA-256 校验通过。Finder 图标位置和五语背景已检查，包内 app 的文件、权限和链接与已发布原 app 完全一致。原 ZIP / appcast / Homebrew 更新包未替换。
CI 39130305280 包含 universal 构建、172 项自测及 DMG 生成/挂载验证，全部通过。正常 brew 卸载→同路径手动安装的临时来源检测通过。用户设置/账号保留已核对实现和 cask 卸载规则，登录项与系统权限例外已写明。

## 用户说明整理

- [x] README 和下载页默认推荐 DMG，说明自动更新和 Homebrew 可选方式。
- [x] 移除用户说明中的发布、公证、密钥、构建和测试流程，保留开发者文档。
- [x] 同步当前 Release 和以后发布的说明模板，核对链接后提交。

用户说明 Review：README 和当前 Release 均为 DMG 优先，保留安装/使用/更新及数据保留说明；开发流程留在 CONTRIBUTING。已核对公开 DMG 链接、线上 Release 内容，实际渲染后续 Release 模板并通过 actionlint 与 diff 格式检查。未修改应用或安装包。
