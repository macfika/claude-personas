# Claude Personas

[English](README.md) | **简体中文**

在 Mac 菜单栏中管理多个 Claude Desktop 账号，在工作、个人和其他配置之间切换。

需要 **macOS 15 或更新版本**，并已安装官方 [Claude Desktop](https://claude.ai/download)。支持 Apple silicon 和 Intel Mac。

## 安装（推荐 DMG）

[**下载 Claude Personas DMG**](https://github.com/macfika/claude-personas/releases/download/v0.3.0/ClaudePersonas-0.3.0.dmg) · [查看最新版本](https://github.com/macfika/claude-personas/releases/latest)

1. 下载后双击 DMG。
2. 按窗口中的箭头，将 **Claude Personas** 拖到右侧 **Applications（应用程序）**。
3. 等待复制完成，从“应用程序”打开 Claude Personas，然后推出安装磁盘。

推荐使用 DMG 安装，之后应用会自动检查更新，也可以在设置中选择“检查更新…”。无需每次重新下载安装包。请从“应用程序”打开应用，不要直接在安装磁盘中运行。

## 开始使用

1. 点击菜单栏中的星号图标，默认配置使用已有的 Claude 账号。
2. 选择“新建配置”，输入如 `Work` 的名称，然后登录另一个账号。
3. 点击配置打开或切换到对应窗口；顶部开关可以全部打开或退出。
4. 右键配置可以改名、排序、设置颜色、打开数据目录或从列表移除。

新建配置需要单独登录。“复制为新配置”会复制原配置的登录状态、聊天数据和设置，副本最初仍属于同一账号。

## 主要功能

- 多个 Claude 账号使用各自的数据目录，同时运行并显示状态。
- 为配置设置名称、颜色和启动偏好，创建独立的 Dock 与应用程序启动器。
- 支持复制配置、复制 MCP 服务器设置，以及为 Claude Code 使用独立配置。
- 可开启菜单栏快捷键、配置快捷键和登录时启动。
- 支持简体中文、繁体中文、日语、韩语和英语，默认跟随系统语言；在“设置 → 语言”中切换。

Claude Code 功能需要另行安装并登录 `claude` 命令行工具。

## 更新

**DMG 安装：** 默认自动检查更新，按应用中的提示完成更新。可在设置中关闭自动检查，或随时选择“检查更新…”。如果以前关闭过自动检查，重新安装后仍会保留该选择。

**Homebrew 安装：** 在应用中选择“使用 Homebrew 更新”，或在终端运行：

```bash
brew update
brew upgrade --cask macfika/claude-personas/claude-personas
```

## Homebrew 安装（可选）

习惯使用 Homebrew 的用户也可以通过终端安装：

```bash
brew tap macfika/claude-personas https://github.com/macfika/claude-personas
brew install --cask macfika/claude-personas/claude-personas
```

### 从 Homebrew 改为 DMG 安装

先退出 Claude Personas，再运行普通卸载：

```bash
brew uninstall --cask macfika/claude-personas/claude-personas
```

随后按上面的 DMG 步骤安装。**设置、配置列表和账号数据会保留**，之后可使用应用内自动更新。不要额外删除应用数据或使用清理工具清除设置；登录时启动和系统权限可能需要重新启用。

## 数据与隐私

从列表移除配置不会删除其数据。默认账号数据位于 `~/Library/Application Support/Claude`，其他配置通常位于同级的 `Claude-<名称>`。删除数据前可在配置菜单中打开对应目录确认内容。

应用没有统计分析功能。管理配置和登录时会读取相关进程、配置文件、受支持的 shell alias 及 Claude 登录日志；检查更新时会连接 GitHub 获取更新。复制配置会同时复制其中的登录状态和聊天数据，请确认目标配置。

## 帮助与贡献

遇到问题请提交 [Issue](https://github.com/macfika/claude-personas/issues)，并注明 macOS 版本、应用版本和复现步骤。日志可能包含个人路径，分享前请检查。

开发者请查看 [贡献指南](CONTRIBUTING.md)。

## 许可与归属

[Apache License 2.0](LICENSE)。基于 [MultiClaude](https://github.com/QuentinCar0n/multiclaude)，归属和第三方许可见 [NOTICE](NOTICE)。

Claude 是 Anthropic 的商标。本项目是独立工具，与 Anthropic 无隶属、赞助或认可关系。
