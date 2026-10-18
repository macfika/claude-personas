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

Apple 公证已 Accepted（提交 ID `96ea9d65-5088-419b-a4a7-a48ec23f75c9`），原应用及最终 ZIP 解压副本的 stapler validate 通过。spctl 显示 Notarized Developer ID；本机全局 Gatekeeper 策略另有 security disabled override，因此还需在独立 CI runner 对正式包再次检查。最终 ZIP SHA-256：`449febd5f6c7b705cb1bee71adf25cdae80e9aa300057960f71418ed69f41d5f`。没有更改系统安全设置。

尚未执行生产 appcast 下载升级、旧版真实迁移或 Homebrew upgrade。隔离 fixture 不证明真实 Claude 窗口保留。

按 CONTRIBUTING.md 通过草稿 ZIP 和同 tag 的 `archive_release` 工作流发布，再补充正式发行和升级验证。真实多账号登录、SSO 与 Claude 自身更新恢复也仍需测试账号验收。
