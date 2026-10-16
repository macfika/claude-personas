# 贡献指南

欢迎提交 [Issue](https://github.com/macfika/claude-personas/issues) 和 Pull Request。请使用测试账号和临时目录复现问题，避免在 Issue 中上传聊天、登录令牌或未经检查的日志。

## 来源与许可

本项目基于 [MultiClaude](https://github.com/QuentinCar0n/multiclaude) 的 Apache 2.0 源码，基线为 `dfb986a16b02b07d0b45d07fbed89a18ab52e396`。请保留 LICENSE、NOTICE 及源码中的来源与修改声明。提交贡献默认使用本项目 Apache 2.0 许可。

## 本地开发

需要 macOS 15+、Swift 6.2+、macOS 15+ SDK（Xcode / Command Line Tools）、已安装的官方 Claude Desktop。

```bash
git clone https://github.com/macfika/claude-personas.git
cd claude-personas
./build.sh --no-install
./scripts/test.sh
```

默认 `./build.sh` 只构建。使用 `./build.sh --install` 才会安装到 `~/Applications` 并启动。主要产物为 `build/ClaudePersonas.app` 和 `build/ClaudePersonas-0.2.0.zip`；应用可执行文件为 `Contents/MacOS/ClaudePersonas`。

SwiftUI 视图和 AppKit 集成位于 `Sources/ClaudePersonas`，没有第三方 Swift 依赖。修改优先保持简单，避免触碰官方 Claude.app 的签名内容；不要在安装或更新脚本中自动移除 quarantine。

## 验证要求

运行构建、自测和与修改相关的人工步骤，参考 [功能对照及验收](docs/feature-parity.md)。PR 中说明改了什么、解决什么问题、运行了哪些检查，以及哪些行为没有实测。自测使用模拟登录日志、临时目录和测试 bundle，不应宣称它证明了真实 Google/SSO 登录、双账号隔离或 Claude 自更新恢复。

```bash
lipo -archs build/ClaudePersonas.app/Contents/MacOS/ClaudePersonas
codesign --verify --deep --strict build/ClaudePersonas.app
```

需要 UI 预览时可以使用示例配置：

```bash
CLAUDE_PERSONAS_DEMO=1 CLAUDE_PERSONAS_PREVIEW=panel \
  build/ClaudePersonas.app/Contents/MacOS/ClaudePersonas
```

演示模式的画面和运行标记是样例，不代表真实账号已登录。

## 发布

1. 更新版本配置与 CHANGELOG，确保 tag、应用版本、ZIP 名称及 Homebrew cask 版本一致。
2. 在 macOS 上运行构建与测试，检查通用二进制、bundle ID `com.macfika.claude-personas` 和签名完整性，并记录人工验收情况。
3. 配置匹配 `Config/update-public-key.txt` 公钥的 GitHub Actions `release` environment secret **UPDATE_SIGNING_KEY**。它应包含 Ed25519 原始 32 字节私钥的 Base64 字符串，不能使用上游 MultiClaude 的私钥或公钥。
4. 推送版本 tag（首版为 `v0.1.0`），检查 `.github/workflows/release.yml` 的结果与 Release 附件，确认 ZIP 和对应 `.zip.sig` 都存在。
5. 发布工作流会将同仓库 `Casks/claude-personas.rb` 的版本、下载地址与 SHA-256 更新并提交到 `main`。检查其对应实际 ZIP，并完成一次从 tap 安装的验证。

Ed25519 签名验证的是发布包与项目更新密钥的关系，不能代替 Apple Developer ID 签名或公证。发布说明必须准确说明当前为 ad-hoc 签名、未公证。

签名工具通过 `CLAUDE_PERSONAS_SIGNING_KEY` 环境变量读取私钥，`--sign-update <zip>` 输出 Base64 签名；`--verify-update <zip> <signature-file>` 使用 app 内置公钥验签。CI 将 secret 传给签名步骤。不要把私钥写进源码、日志、提交或 Release 附件，也不要在 PR 中设置它。

公钥会进入构建后的应用。如果更换公钥，已安装应用不能直接信任新密钥签名的更新；需要单独设计迁移路径，不能只替换公钥文件就宣称兼容。

## 界面翻译

界面文案位于 `Sources/ClaudePersonas/Resources/<语言>.lproj/Localizable.strings`，五种语言的 key 必须一致。通过 `L("English source text", ...)` 取值，动态参数使用 `%@`，需要调整顺序时使用 `%1$@` 等位置参数；不要拼接用户内容作为 key。用户配置名、路径和 shell alias 不参与翻译。

`--selftest-localization` 检查语言回退、选择持久化、资源覆盖及格式参数。完整构建和自测仍使用 `./build.sh --no-install` 和 `./scripts/test.sh`。演示时可设置 `CLAUDE_PERSONAS_DEMO=1 CLAUDE_PERSONAS_LANGUAGE=ja`，支持 `zh-Hans`、`zh-Hant`、`ja`、`ko`、`en` 和 `system`；此环境变量仅在演示模式下生效。
