# Claude Personas

用 SwiftUI 和 AppKit 编写的 macOS 菜单栏工具，为 Claude Desktop 的多个账号分别管理配置目录、窗口和启动器。

本项目基于 [QuentinCar0n/multiclaude](https://github.com/QuentinCar0n/multiclaude) 的 Apache 2.0 源码适配，基线提交为 [`dfb986a16b02b07d0b45d07fbed89a18ab52e396`](https://github.com/QuentinCar0n/multiclaude/tree/dfb986a16b02b07d0b45d07fbed89a18ab52e396)。保留其主要功能，拆分 Swift 源文件，并使用独立的应用标识、发布渠道和更新签名。原作者归属见 [NOTICE](NOTICE)，不是完全从零编写的实现。

需要 **macOS 15+** 和官方 [Claude Desktop](https://claude.ai/download)，建议将 `Claude.app` 安装到 `/Applications`。发布包为 Apple silicon / Intel 通用应用。Claude Code 功能另需已安装 `claude` CLI。

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

当前构建使用 ad-hoc 代码签名，**尚无 Apple Developer ID 签名或 Apple 公证**。首次打开可能被 Gatekeeper 阻止：先尝试打开，再进入“系统设置 → 隐私与安全性”，确认来源后选择“仍要打开”。安装流程不会自动移除 quarantine，也不会修改系统安全策略。独立的更新包签名不等于 Apple 公证。

## 使用

1. 点击菜单栏图标，默认配置使用现有 Claude 的账号和数据目录。
2. 选择 **New Profile**，输入如 `Work` 的名称并回车，打开后登录另一个账号。
3. 再次点击已运行配置会聚焦其窗口；悬停退出按钮关闭该配置；顶部开关可以全部打开或退出。
4. 右键配置可改名、调整顺序、改颜色、打开数据目录、复制 shell alias，或从列表移除。

应用界面目前使用英文。新建配置不会自动复制已有登录；**Duplicate as New Profile** 则会复制登录状态、聊天数据和设置，复制出的配置最初属于同一账号。

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
- 登录时启动、明暗外观、菜单栏颜色及数量设置；可选的后台签名更新。

完整对照、边界和人工验收步骤见 [功能对照表](docs/feature-parity.md)。真实双账号登录、Google/SSO 回调、Claude 实际更新后的恢复，以及应用自更新替换重启仍需端到端验证；不能把通过自测理解为这些操作已经实测成功。

已完成的构建、93 项自测、演示界面、正式包 Homebrew 安装/卸载及隔离副本签名更新检查，见 [0.1.0 验证记录](docs/validation.md)。

## 数据与隐私

配置列表和设置存储在应用偏好域 `com.macfika.claude-personas`。默认账号数据位于 `~/Library/Application Support/Claude`；其他配置通常位于同级的 `Claude-<名称>`。**Remove from List** 保留数据目录。彻底删除某个配置前，请先打开其数据目录、退出该配置，再从列表移除并自行处理目录。

启动器位于 `~/Applications/ClaudePersonas Launchers`；运行副本位于 `~/Library/Application Support/ClaudePersonas/Runtimes.noindex`。APFS 克隆起初共享文件块，之后随修改增加磁盘占用；不支持克隆时会回退到普通 Claude 启动，配置独立图标可能不可用。不会修改原始 `/Applications/Claude.app` 的签名内容。

没有统计分析功能。启用自动更新后会访问本仓库的 GitHub Releases API、下载包和签名。应用会读取 `~/.zshrc`、进程参数、配置文件及 Claude 登录日志；复制配置时会处理含登录状态和聊天记录的数据目录。登录路由可能调整 `claude://` 的默认处理程序，正常退出时会归还 Claude。自己的诊断日志位于 `~/Library/Logs/ClaudePersonas.log`，链接查询参数会被遮蔽。提交问题时请自行检查并移除日志中的个人路径等信息。

## 从源码构建

需要 Xcode Command Line Tools，包含 **Swift 6.2+** 和 macOS 15+ SDK；无需第三方 Swift 依赖。

```bash
git clone https://github.com/macfika/claude-personas.git
cd claude-personas
./build.sh --no-install
./scripts/test.sh
```

`./build.sh` 默认也只构建，输出 `build/ClaudePersonas.app` 和 `build/ClaudePersonas-0.1.0.zip`。只有显式执行 `./build.sh --install` 才安装到 `~/Applications` 并启动。

代码位于 [Sources/ClaudePersonas](Sources/ClaudePersonas)。可使用 Xcode 打开 `Package.swift` 编辑与调试；可分发的菜单栏应用请使用 `build.sh` 打包。贡献及发布流程见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 更新与发布

使用 Homebrew 安装的用户可以通过 `brew upgrade` 更新。应用内 **Update Claude Personas Automatically** 是可选设置，构建包含本项目更新公钥时默认开启；可以在设置中关闭。启用后启动时检查，并在运行期间约每天检查一次。安装前验证独立 Ed25519 签名、bundle ID、版本和代码签名，再替换应用并在面板关闭时重启；Claude 窗口保持运行。

更新公钥位于 [Config/update-public-key.txt](Config/update-public-key.txt)，不复用 MultiClaude 的更新信任根。发布需配置匹配私钥的 GitHub Actions secret `UPDATE_SIGNING_KEY`；仅有 tag 或 ZIP 并不足以生成可信的应用内更新。私钥绝不能提交到仓库。

## 许可与归属

[Apache License 2.0](LICENSE)。基于 Soma Labs / QuentinCar0n 的 MultiClaude，Claude Personas 的修改由 macfika 维护，详见 [NOTICE](NOTICE)。

Claude 是 Anthropic 的商标。本项目是独立工具，与 Anthropic 无隶属、赞助或认可关系。
