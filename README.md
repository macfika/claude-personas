# Claude Personas

用 SwiftUI 和 AppKit 编写的 macOS 菜单栏工具，为 Claude Desktop 的多个账号分别管理配置目录、窗口和启动器。

本项目基于 [QuentinCar0n/multiclaude](https://github.com/QuentinCar0n/multiclaude) 的 Apache 2.0 源码适配，基线提交为 [`dfb986a16b02b07d0b45d07fbed89a18ab52e396`](https://github.com/QuentinCar0n/multiclaude/tree/dfb986a16b02b07d0b45d07fbed89a18ab52e396)。保留其主要功能，拆分 Swift 源文件，并使用独立的应用标识、发布渠道和更新签名。原作者归属见 [NOTICE](NOTICE)，不是完全从零编写的实现。

需要 **macOS 15+** 和官方 [Claude Desktop](https://claude.ai/download)，建议将 `Claude.app` 安装到 `/Applications`。发布包为 Apple silicon / Intel 通用应用。Claude Code 功能另需已安装 `claude` CLI。

**0.3.0** 引入按安装来源区分的更新通道：手动安装使用 Sparkle，Homebrew 安装通过 brew 更新；菜单栏统一使用单色图标。

## 安装

### Homebrew

本仓库同时提供 tap，因此首次安装需要显式指定仓库地址：

```bash
brew tap macfika/claude-personas https://github.com/macfika/claude-personas
brew install --cask macfika/claude-personas/claude-personas
```

后续更新：

```bash
brew update
brew upgrade --cask macfika/claude-personas/claude-personas
```

### 手动安装

从 [Releases](https://github.com/macfika/claude-personas/releases/latest) 下载 `ClaudePersonas-<版本>.zip`，解压后把 `ClaudePersonas.app` 拖入 `/Applications` 或 `~/Applications`，然后打开。

0.3.0 正式包使用 Developer ID 签名并通过 Apple 公证，生产发布流程还会验证 stapled 公证票据和 Gatekeeper 结果。安装流程不会自动移除 quarantine，也不会修改系统安全策略。

旧版 0.2.1 及更早的包使用 ad-hoc 签名、未公证。若打开旧版时被 Gatekeeper 阻止，先尝试打开，再进入“系统设置 → 隐私与安全性”，确认来源后选择“仍要打开”。Ed25519 更新签名与 Apple 签名、公证各有用途。

## 使用

1. 点击菜单栏图标，默认配置使用现有 Claude 的账号和数据目录。
2. 选择 **New Profile**，输入如 `Work` 的名称并回车，打开后登录另一个账号。
3. 再次点击已运行配置会聚焦其窗口；悬停退出按钮关闭该配置；顶部开关可以全部打开或退出。
4. 右键配置可改名、调整顺序、改颜色、打开数据目录、复制 shell alias，或从列表移除。

应用默认跟随系统语言，支持简体中文、繁体中文、日语、韩语和英语。展开“设置 / Settings”，在“语言 / Language”中切换；选择立即生效并保存，选择“跟随系统”可恢复自动匹配。不支持的系统语言回退到英语。语言名称以各自语言显示，方便切换回来。切换界面语言不会更改配置名称、数据目录或 Claude Desktop 本身的语言。

新建配置不会自动复制已有登录；**Duplicate as New Profile** 则会复制登录状态、聊天数据和设置，复制出的配置最初属于同一账号。

## 功能

- 每个配置独立使用 `--user-data-dir`；实时显示运行状态、打开数量和当前前台账号。
- 配置颜色、改名、排序、目录自动发现；首次识别 `~/.zshrc` 中受支持格式的 Claude alias。
- 单个启动、聚焦、退出，以及全部启动/退出；可为指定配置设置随 Claude Personas 启动。
- **App for Each Profile** 生成每个账号的启动器，支持 Spotlight、Launchpad、Dock、自定义启动器名称和彩色图标。
- 启用配置启动器后，为每个配置创建 Claude.app 的运行副本，以独立图标显示在 Dock、⌘-Tab 和 Mission Control；运行中的应用名称仍是 Claude。
- Google / SSO 登录路由及窗口内登录；Claude 更新后尝试恢复原配置。
- 为 Claude Code 设置独立 `CLAUDE_CONFIG_DIR`，从 Terminal 启动或复制 alias；CLI 登录需要单独完成。
- 配置复制、MCP 服务器复制与目标配置备份；重命名目录后保留旧路径符号链接。
- 菜单栏快捷键 `⌃⌥⌘M`，前九个配置快捷键 `⌃⌥1` 至 `⌃⌥9`，需要在设置中开启。
- 登录时启动、明暗外观、单色菜单栏图标及数量设置；配置和启动器保留各自颜色。
- 手动安装通过 Sparkle 2.10.0 自动更新或“检查更新…”；Homebrew 安装只提供 brew 更新命令。

完整对照、边界和人工验收步骤见 [功能对照表](docs/feature-parity.md)。真实双账号登录、Google/SSO 回调、Claude 实际更新后的恢复仍需端到端验证。已在临时目录、临时密钥和独立 fixture 应用上完成真实 Sparkle 替换与重启验证；正式包的线上 appcast 升级、旧版迁移和升级后 Claude 窗口保留仍待验收。

已完成的构建、153 项自测、演示语言切换、正式包资源与签名检查，见 [0.2.0 验证记录](docs/validation-0.2.0.md)。

## 数据与隐私

配置列表和设置存储在应用偏好域 `com.macfika.claude-personas`。默认账号数据位于 `~/Library/Application Support/Claude`；其他配置通常位于同级的 `Claude-<名称>`。**Remove from List** 保留数据目录。彻底删除某个配置前，请先打开其数据目录、退出该配置，再从列表移除并自行处理目录。

启动器位于 `~/Applications/ClaudePersonas Launchers`；运行副本位于 `~/Library/Application Support/ClaudePersonas/Runtimes.noindex`。APFS 克隆起初共享文件块，之后随修改增加磁盘占用；不支持克隆时会回退到普通 Claude 启动，配置独立图标可能不可用。不会修改原始 `/Applications/Claude.app` 的签名内容。

没有统计分析功能。手动安装启用更新后，Sparkle 会访问本仓库 Release 中的 appcast 和更新包；旧版迁移及只读 CLI 检查使用 GitHub Releases API。Homebrew 安装由 brew 获取更新。应用会读取 `~/.zshrc`、进程参数、配置文件及 Claude 登录日志；复制配置时会处理含登录状态和聊天记录的数据目录。登录路由可能调整 `claude://` 的默认处理程序，正常退出时会归还 Claude。自己的诊断日志位于 `~/Library/Logs/ClaudePersonas.log`，链接查询参数会被遮蔽。提交问题时请自行检查并移除日志中的个人路径等信息。

## 从源码构建

需要 Xcode Command Line Tools，包含 **Swift 6.2+** 和 macOS 15+ SDK；依赖固定版本的 Sparkle 2.10.0；`build.sh` 首次运行会从其官方 GitHub Release 下载框架，验证固定 SHA-256 后缓存到 `.build/sparkle`。

```bash
git clone https://github.com/macfika/claude-personas.git
cd claude-personas
./build.sh --no-install
./scripts/test.sh
```

`./build.sh` 默认也只构建，输出 `build/ClaudePersonas.app` 和 `build/ClaudePersonas-0.3.0.zip`。只有显式执行 `./build.sh --install` 才安装到 `~/Applications` 并启动。

代码位于 [Sources/ClaudePersonas](Sources/ClaudePersonas)。可使用 Xcode 打开 `Package.swift` 编辑与调试；可分发的菜单栏应用请使用 `build.sh` 打包。贡献及发布流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 更新与发布

0.3.0 按当前应用副本的安装来源选择更新方式：

| 安装来源 | 设置中入口 | 更新方式 |
| --- | --- | --- |
| 手动安装 Release ZIP | 自动更新开关、“检查更新…” | Sparkle 检查 appcast、验签、安装并重启 |
| Homebrew 安装 | “使用 Homebrew 更新”，可复制命令 | `brew update && brew upgrade --cask macfika/claude-personas/claude-personas` |
| Homebrew 收据损坏或缺失，但路径指向该副本 | 提示安装记录无法验证 | 保守禁用应用内更新，先检查/修复 brew 安装记录 |
| 仓库 build 目录或 SwiftPM 调试运行 | 更新不可用 | 重新构建 |

检测同时检查 Caskroom 路径、符号链接以及指向该副本的 appdir 和安装收据；同一台机器另装了 cask 不会让无关手动副本自动归 Homebrew 管理。Homebrew cask 不声明 `auto_updates`，应用不会用 Sparkle 替换 brew 管理的包。

0.2.x 尚无安装来源分流。现有 Homebrew 用户应先关闭旧版应用的自动更新，再通过上述 brew 命令升级到 0.3.0；新版本会继续由 Homebrew 管理。

手动安装的自动检查默认启用，旧版明确关闭的偏好会迁移，可在设置中关闭。更新提示和安装由 Sparkle 管理；出错会在界面显示。更新重启会保留 Claude 配置窗口。`--check-update` 只读取最新发布信息，不下载或安装应用；`--update-now` 已禁用并返回非零退出码，请使用 GUI 或 brew。

更新公钥位于 [Config/update-public-key.txt](Config/update-public-key.txt)。Sparkle appcast 使用原有项目 Ed25519 seed 签名，同时保留 `.zip.sig` 供 0.2.x 迁移；生成步骤核对两者签名一致，不复用 MultiClaude 的信任根。发布依赖 `release` environment 的 `UPDATE_SIGNING_KEY`，并要求正式包先通过 Developer ID、公证票据和 Gatekeeper 检查。维护者可在本机完成签名公证，再将 ZIP 交给 CI 发布，无需导出证书；具体命令见 [贡献与发布指南](CONTRIBUTING.md)。私钥绝不能提交到仓库。

## 许可与归属

[Apache License 2.0](LICENSE)。基于 Soma Labs / QuentinCar0n 的 MultiClaude，Claude Personas 的修改由 macfika 维护，详见 [NOTICE](NOTICE)。

包含 [Sparkle 2.10.0](https://github.com/sparkle-project/Sparkle/tree/2.10.0)，其主许可为 MIT，所附第三方组件含 BSD 等许可；原始许可全文随应用打包为 `Contents/Resources/Sparkle-LICENSE`。

Claude 是 Anthropic 的商标。本项目是独立工具，与 Anthropic 无隶属、赞助或认可关系。
