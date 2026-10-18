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

默认 `./build.sh` 只构建。使用 `./build.sh --install` 才会安装到 `~/Applications` 并启动。主要产物为 `build/ClaudePersonas.app` 和 `build/ClaudePersonas-0.3.0.zip`；图形安装包由 `./scripts/build-dmg.sh build/ClaudePersonas.app` 另行生成 `build/ClaudePersonas-0.3.0.dmg`；应用可执行文件为 `Contents/MacOS/ClaudePersonas`。

SwiftUI 视图和 AppKit 集成位于 `Sources/ClaudePersonas`，依赖固定版本 Sparkle 2.10.0。`scripts/fetch-sparkle.sh` 下载官方框架并校验固定 SHA-256；SwiftPM 也固定同版本。框架主许可为 MIT，附带 BSD 等第三方组件许可；构建会将完整原始 LICENSE 保存为应用资源 `Sparkle-LICENSE`，请勿遗漏。修改优先保持简单，避免触碰官方 Claude.app 的签名内容；不要在安装或更新脚本中自动移除 quarantine。

DMG 构建工具固定使用 dmgbuild 1.6.7，通过 uv 或独立的 `.build/dmg-tools` Python 虚拟环境运行，不会嵌入应用。720 × 480 的 Finder 窗口包含五语言背景提示、拖拽箭头、指向 `/Applications` 的链接与 `Installation.html`。脚本将已有的签名 app 原样装入磁盘镜像，不重新构建 app。

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

## 更新通道与验证

手动安装副本由 `UpdateController` 启动 Sparkle；Homebrew 和安装记录可疑的副本不启动 Sparkle。识别依据包含 Caskroom artifact、解析后的路径、appdir 和安装收据，不能仅因为机器装了 cask 就关闭其他手动副本的更新。坏收据与丢失收据在明确指向当前副本时保守禁用，开发目录也不自更新。检查与安装边界都会重新验证来源。

`--installation-channel` 可检查当前副本归属。`--check-update` 只读，不下载应用；`--update-now` 已禁用并退出 1。Homebrew 使用 `brew update && brew upgrade --cask macfika/claude-personas/claude-personas`，cask 不应添加 `auto_updates`。

自测之外，可在有图形登录会话的 macOS 上运行：

```bash
./scripts/test-sparkle-update.sh
```

它创建临时密钥、本地 HTTP appcast 和独立 fixture bundle，真实执行 Sparkle 替换及重启并检查新版本和进程。该测试已通过，但不验证生产 Developer ID、公证、正式 appcast 或真实 Claude 账号窗口。

## 发布流程（以 0.3.0 为例）

0.3.0 使用 Developer ID 签名，并已取得 Apple 公证 Accepted 结果。旧版 0.2.1 仍是 ad-hoc 签名、未公证。线上升级和 0.2.x 迁移需要单独验收；签名公证通过不能代替这两项验证。

生产工作流会依次检查完整代码签名、`Developer ID Application` 身份、stapled 公证票据和 Gatekeeper；ad-hoc 构建不能通过发布校验。推 tag 本身不会触发发布，也不会把本地证书带入 CI。当前推荐在有证书的本机完成签名公证，再使用同 tag 草稿传递 ZIP 和 DMG，不需要导出证书给 GitHub。

### 1. 准备本机身份与版本

需要已安装且可用于签名的 Developer ID Application 证书、可用的 Apple 公证凭据和已保存的 notarytool Keychain profile。可先列出本机代码签名身份：

```bash
security find-identity -v -p codesigning
xcrun notarytool store-credentials "claude-personas-notary"
```

第二条按交互提示保存你自己的凭据；不要将密码、证书私钥或 Keychain 内容放入仓库。已有 profile 可直接使用。确认 VERSION 为 `0.3.0`，CHANGELOG 的 `## 0.3.0` 节记录最终行为，发布工作流和生成 appcast 脚本已经包含在准备发布的提交中。

### 2. 构建、签名、公证和验证

把下方示例身份替换为 `security find-identity` 输出中的真实 Developer ID：

```bash
CODESIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='claude-personas-notary' ./build.sh --no-install
./scripts/test.sh
codesign --verify --deep --strict build/ClaudePersonas.app
codesign --display --verbose=2 build/ClaudePersonas.app
xcrun stapler validate build/ClaudePersonas.app
spctl --assess --type execute --verbose build/ClaudePersonas.app
```

脚本按由内到外的顺序签名 Sparkle helper、框架和主应用；使用 Developer ID 时启用 hardened runtime 与时间戳。设置 `NOTARY_PROFILE` 后提交公证、等待结果、staple，再生成 `build/ClaudePersonas-0.3.0.zip`。没有设置身份时只是本地 ad-hoc 构建，不具备生产发布资格。不要在此后修改 ZIP 或应用内容。

### 3. 从同一应用生成图形 DMG

保留上一步已签名公证的 app，运行：

```bash
CODESIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE='claude-personas-notary' \
  ./scripts/build-dmg.sh build/ClaudePersonas.app
./scripts/verify-dmg.sh build/ClaudePersonas-0.3.0.dmg \
  build/ClaudePersonas.app --production
```

DMG 使用 Developer ID Application 签名，并单独提交公证和 staple。校验脚本验证镜像完整性、签名、公证票据及 Gatekeeper，以只读方式挂载，检查 Applications 链接、背景、Finder 布局和说明文件，并比较其中 app 与指定 app 完全一致。CI 也会构建及验证开发 DMG；正式发布另有 `--production` 门槛。

ZIP 继续用于 Sparkle 更新和 Homebrew，DMG 用于普通用户的图形安装；两个文件应包含相同的签名 app。

### 4. 上传同 tag 的草稿并交给 CI

确保准备发布的提交已推送到 `main`。以下命令适用于首次创建该 tag 和草稿；已有同名 tag 或草稿时先确认其提交及附件，勿覆盖错误版本。

```bash
git tag v0.3.0
git push origin v0.3.0
gh release create v0.3.0 build/ClaudePersonas-0.3.0.zip \
  build/ClaudePersonas-0.3.0.dmg \
  --repo macfika/claude-personas --draft --verify-tag \
  --title 'Claude Personas 0.3.0' --notes 'Pending production verification.'
gh workflow run release.yml --repo macfika/claude-personas \
  --ref v0.3.0 -f archive_release=v0.3.0
```

主线 CI 负责构建和自测；推 tag 仅建立版本引用。上述显式 dispatch 使用 `archive_release`，从同 tag 的草稿下载已经签名公证的 ZIP 和 DMG，缺少任一附件均不能完成发布。输入必须等于运行 ref `v0.3.0`，且对应 Release 必须仍为草稿；不要提前手动发布。

CI 需要 `release` environment secret **UPDATE_SIGNING_KEY**，内容为与 `Config/update-public-key.txt` 匹配的 Base64 编码 32 字节 Ed25519 seed。此密钥与本机 Apple 签名证书各有用途。流程验证 ZIP 中的 app，并以 `verify-dmg.sh --production` 对照校验 DMG 后，使用 seed 生成旧版 `.zip.sig` 和 Sparkle `appcast.xml`，分别验证两种签名均被相同公钥信任，再生成 `sha256.txt`，将草稿发布为 latest，并提交同仓库 `Casks/claude-personas.rb` 的版本与 SHA-256 更新到 `main`。

```bash
gh run list --repo macfika/claude-personas --workflow release.yml --limit 5
gh run watch RUN_ID --repo macfika/claude-personas --exit-status
gh release view v0.3.0 --repo macfika/claude-personas
```

将 `RUN_ID` 替换为对应 dispatch 运行编号。发布后检查 DMG、ZIP、`.zip.sig`、`sha256.txt`、`appcast.xml` 五项附件，完成正式包首次安装、从 0.2.x 迁移、Sparkle 更新和 Homebrew upgrade 验收，记录未完成项。

### 为已发布的 0.3.0 补充 DMG

0.3.0 已发布 ZIP 时，先下载并解压该正式 ZIP，以其中的签名 app 作为 `build-dmg.sh` 输入，再用上一节的生产命令签名公证及校验 DMG。确认版本与内容对应后，仅添加新附件：

```bash
gh release upload v0.3.0 build/ClaudePersonas-0.3.0.dmg \
  --repo macfika/claude-personas
```

保留现有 ZIP、`.zip.sig`、appcast、cask 及其校验值，不重建或替换更新包。已发布 Release 不使用要求草稿的 `archive_release` 流程。上述命令不带 `--clobber`，已有同名附件时应先核对原因。

### 密钥和 appcast 兼容性

Sparkle feed 地址为 `https://github.com/macfika/claude-personas/releases/latest/download/appcast.xml`。`scripts/generate-appcast.py` 使用现有项目 seed，保留之前 appcast 条目并要求新 CFBundleVersion 递增；默认 build 编号由语义版本计算。旧 0.2.x 仍读取 GitHub API 和 `.zip.sig` 以迁移到新版本。

`--sign-update <zip>` 从 `CLAUDE_PERSONAS_SIGNING_KEY` 环境变量读取 seed，`--verify-update <zip> <signature-file>` 使用内置公钥验签；CI 负责传递 secret。不要将私钥写入源码、日志、PR 或 Release。更换公钥需要专门的客户端迁移策略，不能只替换文件。Ed25519 更新签名不能代替 Apple 签名、公证或 Gatekeeper 检查。

## 界面翻译

界面文案位于 `Sources/ClaudePersonas/Resources/<语言>.lproj/Localizable.strings`，五种语言的 key 必须一致。通过 `L("English source text", ...)` 取值，动态参数使用 `%@`，需要调整顺序时使用 `%1$@` 等位置参数；不要拼接用户内容作为 key。用户配置名、路径和 shell alias 不参与翻译。

`--selftest-localization` 检查语言回退、选择持久化、资源覆盖及格式参数。完整构建和自测仍使用 `./build.sh --no-install` 和 `./scripts/test.sh`。演示时可设置 `CLAUDE_PERSONAS_DEMO=1 CLAUDE_PERSONAS_LANGUAGE=ja`，支持 `zh-Hans`、`zh-Hant`、`ja`、`ko`、`en` 和 `system`；此环境变量仅在演示模式下生效。
