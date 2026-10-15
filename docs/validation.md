# 0.1.0 验证记录

验证日期：2026-10-16（日本时间）。以下记录区分实际通过的检查与尚未完成的账号验收。

## 已通过

- 本机 Swift 6.4 编译，以及 `swift build` 的 Swift Package 构建。
- `./build.sh --no-install` 生成 macOS 15+ 的 arm64 / x86_64 通用应用。
- 六组核心自测共 93 项断言通过：更新恢复决策、版本、配置复制与 MCP、登录日志识别、启动器与运行副本、签名与更新来源。
- `codesign --verify --deep --strict`、Info.plist 和通用架构检查。
- 演示模式下检查面板布局、新建 `Demo QA` 配置、点击配置后的运行状态变化及退出。
- [GitHub CI](https://github.com/macfika/claude-personas/actions/runs/38783897615) 使用 Swift 6.2 工具链构建并测试通过。
- [Release 工作流](https://github.com/macfika/claude-personas/actions/runs/38783982090) 构建、测试、Ed25519 签名、验签和发布成功，并自动更新 Homebrew cask 的 SHA-256。
- Homebrew tap 与 cask 审核通过；从正式 Release 下载并安装到临时应用目录，确认版本 `0.1.0`、两种架构及签名完整性，随后成功卸载。
- 将本地应用复制到临时测试目录，设置 `CLAUDE_PERSONAS_FAKE_VERSION=0.0.0` 后执行 `--update-now`：成功检查 Release、下载、验签、校验 bundle 并替换为正式 `0.1.0` 包；替换后代码签名仍通过。此项未执行 GUI 自动重启。

正式发布文件 `ClaudePersonas-0.1.0.zip` 的 SHA-256：

```text
8e17f00f2b9fe62581d19cb67c9f4ddc866f839b4e16badddba33e28ff3a68dd
```

## 尚需人工验收

真实双账号独立登录、Google/SSO 回调、真实 Claude 升级后的恢复、Dock/Spotlight 和登录项、自动更新后的 GUI 重启及窗口保留、Intel 实机运行，以及有隔离账号数据的 Homebrew 跨版本升级。

尚无 Developer ID 签名或 Apple 公证。完整验收步骤见 [功能对照表](feature-parity.md)。
