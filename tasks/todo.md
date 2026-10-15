# Claude Personas

- [x] 对照上游功能并记录源码来源、许可和差异。
- [x] 适配 SwiftUI 应用，拆分源文件，隔离身份、数据和更新信任。
- [x] 配置通用二进制构建、测试、GitHub Release 和 Homebrew cask。
- [x] 编译并运行核心自测，验证打包与安装路径。
- [ ] 发布到 macfika/claude-personas，验证 Homebrew 安装（取决于仓库权限）。

## Review

本机 Swift 6.4 严格并发编译，arm64/x86_64 通用应用，93 项自测断言通过；codesign 和 Info.plist 检查通过。
演示模式下已检查面板布局、创建配置及点击启动的状态更新。真实账号登录、SSO、Claude 自动升级恢复未验收。
源码已推送，GitHub CI 及首次 Release / Homebrew 实际安装验证进行中。
