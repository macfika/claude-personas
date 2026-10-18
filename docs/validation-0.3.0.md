# 0.3.0 验证记录

验证日期：2026-10-18。本机 macOS，Xcode Swift 工具链。

## 已通过

- `swift build`：SwiftPM 使用固定 Sparkle 2.10.0，编译通过。
- `CODESIGN_IDENTITY=… ./build.sh --no-install`：arm64/x86_64 通用构建通过。
- `./scripts/test.sh`：172 项断言通过，含 19 项安装来源检测；Info.plist、主程序与 Sparkle 双架构、框架符号链接、更新配置和完整签名通过。
- Developer ID Application: LI KE (FKKCZM5CBJ)，主应用与 Sparkle helper 由内向外签名，主应用启用 hardened runtime 与安全时间戳。未将证书私钥导出到 CI。
- `/Applications/ClaudePersonas.app` 只读来源检测为 `homebrew`；没有替换或退出用户已安装应用。
- `./scripts/test-sparkle-update.sh`：临时密钥、127.0.0.1 feed、独立随机 bundle ID 和临时目录的真实更新通过。旧进程 PID 83079/v1 退出，Sparkle 下载、验签、解压并原路径替换，新 PID 83159/v2 启动写入 marker 后退出，磁盘版本与 codesign 验证通过。
- 中文隔离演示：新增更新行的图标、标题起点与现有设置一致，开发构建说明可见；彩色菜单栏设置已移除。使用独立偏好域与始终强制 demo 环境的启动 wrapper，没有接触真实账号数据。
- 发布 YAML、shell、Python、Ruby cask 语法及 `git diff --check` 通过。发布流程对实际 ZIP 校验 tag、VERSION、bundle ID/版本、自测、双架构、Developer ID、公证票据和 Gatekeeper。

## 验证边界

Apple 公证已 Accepted（提交 ID `96ea9d65-5088-419b-a4a7-a48ec23f75c9`），原应用及最终 ZIP 解压副本的 stapler validate 通过。spctl 显示 Notarized Developer ID；本机全局 Gatekeeper 策略另有 security disabled override，独立 GitHub runner 已再次检查正式 ZIP，完整签名、票据和 Gatekeeper 都通过。最终 ZIP SHA-256：`449febd5f6c7b705cb1bee71adf25cdae80e9aa300057960f71418ed69f41d5f`。没有更改系统安全设置。

发布后下载的 ZIP 与 SHA-256、旧 `.zip.sig`、最新 appcast 的版本/长度/下载地址及 Sparkle enclosure 签名全部通过验证。

将真实 0.2.1 Release 解压到临时目录，通过其原有只更新当前副本的 CLI 成功迁移到线上 0.3.0，并验证磁盘版本与完整代码签名；没有启动生产 GUI、替换 /Applications 副本或接触真实账号。

`brew fetch --cask` 通过 0.3.0 下载校验，默认 `brew outdated --cask --verbose` 明确输出 `claude-personas (0.2.1) != 0.3.0`，证明移除 auto_updates 后 Homebrew 能管理升级。没有执行真实安装的 brew upgrade，以保留用户正在运行的应用。隔离 fixture 不证明真实 Claude 窗口保留。

0.3.0 已通过同 tag 的 `archive_release` 工作流正式发布，appcast 和 cask 均已上线。

- Release：https://github.com/macfika/claude-personas/releases/tag/v0.3.0
- 成功发布与独立生产包验证：https://github.com/macfika/claude-personas/actions/runs/39129187650
- 最终主线构建及 172 项自测：https://github.com/macfika/claude-personas/actions/runs/39129184397

首次发布尝试在签名兼容性门禁被阻止：CryptoKit 会生成带随机性的有效 Ed25519 签名，不能与 Sparkle 的签名字节比较相等。改为同公钥分别验证旧签名与新签名后发布成功；临时随机 seed 回归覆盖两个不同但有效的 CryptoKit 签名，ZIP SHA-256 保持不变，无需更换密钥或重新公证。真实多账号登录、SSO 与 Claude 自身更新恢复也仍需测试账号验收。
