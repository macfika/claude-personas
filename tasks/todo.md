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
- [ ] 编译、自测与演示切换验证，发布新版并更新 Homebrew。
