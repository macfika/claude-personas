# 与 MultiClaude 的功能对照及验收

对照基线：[QuentinCar0n/multiclaude @ dfb986a16b02b07d0b45d07fbed89a18ab52e396](https://github.com/QuentinCar0n/multiclaude/tree/dfb986a16b02b07d0b45d07fbed89a18ab52e396)。Claude Personas 是此 Apache 2.0 项目的适配版本，SwiftUI 视图运行在 AppKit 菜单栏面板中。

“已保留”表示源码中存在实现；自测检查算法、文件操作或构造的测试数据，不代表已完成真实账号和系统交互验收。下列人工步骤在真实 Claude 与 macOS 上通过之前，应保持未勾选，并在发布记录中写明环境及结果。

| 上游功能 | Claude Personas 实现 | 验证与边界 |
| --- | --- | --- |
| 每账号独立数据目录，保留默认配置 | 已保留；`--user-data-dir` 与默认无参数启动 | 启动参数有自测；真实双账号登录待验收 |
| 点击启动、再次点击聚焦 | 已保留；按 PID 与目录匹配窗口 | 多窗口聚焦待验收 |
| 单个退出、全部启动/退出 | 已保留；菜单栏悬停按钮及总开关 | 人工检查只关闭目标配置 |
| 实时运行状态与数量 | 已保留；系统通知配合轮询 | 人工检查从 alias 启动的进程 |
| 前台账号名称和颜色 | 已保留；监听前台进程变化 | 人工检查账号与颜色映射 |
| 新建、改名、顺序、颜色、Finder、shell alias | 已保留；配置右键菜单 | 名称及特殊字符处理需结合人工检查 |
| 从默认账号、zsh alias 与 Claude-* 目录导入 | 已保留；排除 Claude-3p；定期发现目录 | alias 只支持识别器接受的语法，并非任意 shell 表达式 |
| 移除配置而保留数据 | 已保留；记录排除路径以避免再次导入 | 人工确认目录仍在 |
| 目录跟随改名，旧路径保留符号链接 | 已保留；运行中等待关闭后处理 | 自测覆盖目标冲突、移动、符号链接 |
| 每配置 App、Spotlight、Launchpad、Dock | 已保留；独立 URL scheme 与 launcher ID | 自测覆盖生成、改名、冲突、清理；系统索引与 Dock 待人工验证 |
| 每配置自定义 App 名称与彩色图标 | 已保留；启动器及运行副本 | 自测覆盖图标、改名；运行窗口名称仍为 Claude |
| 保留官方签名的 Claude 运行副本 | 已保留；APFS clone 与外部 Finder 图标 | 自测使用伪造测试 bundle；真实 Claude 签名、Keychain 与图标待验证 |
| Claude 更新后恢复配置 | 已保留；识别版本及异常重启 | 自测覆盖恢复决策；实际 Claude 自更新尚未端到端验证 |
| Claude Code 独立配置和 Terminal 启动 | 已保留；独立 CLAUDE_CONFIG_DIR 与 alias | CLI 需另行安装及登录，不会自动取得 Desktop 的登录凭据 |
| 复制 MCP 服务器 | 已保留；合并 mcpServers，覆盖同名项，先备份 | 自测覆盖合并、保留其他键、备份及损坏 JSON |
| 复制整个账号配置 | 已保留；退出源配置后复制，去除运行锁 | 自测使用临时数据；复制真实登录状态待验收 |
| 启动工具时打开选定配置 | 已保留；每配置 openAtLaunch | 配合 Launch at Login 人工验证 |
| Google/SSO 账号内登录与 URL 回调 | 已保留；claude:// 路由及日志状态识别 | 自测仅覆盖日志样本；真实登录与授权回调尚未端到端验证 |
| 面板与前九配置快捷键 | 已保留；⌃⌥⌘M、⌃⌥1–9 | 默认关闭，需开启并检查系统冲突 |
| 登录时启动、明暗模式、菜单栏设置 | 已保留；SMAppService 与原生外观 | 登录项目权限、系统主题需人工验证 |
| 工具退出时一并退出配置 | 已保留；可选设置 | 人工验证开启/关闭两种行为 |
| 自动更新工具，保留 Claude 窗口 | 已保留；独立仓库与 Ed25519 公钥 | 有本项目公钥时默认开启；签名校验与版本逻辑可自动验证，替换重启待端到端验证 |
| Universal、Homebrew、GitHub Releases | 提供本项目脚本、Casks 与工作流 | macOS arm64 / x86_64；分发包使用 ad-hoc 签名，未公证 |

## 与上游有意不同的部分

- 产品名为 Claude Personas，主 bundle ID 为 `com.macfika.claude-personas`，专用 URL scheme 为 `claude-personas://`。不会导入上游自己的偏好设置，但能发现相同的 Claude 数据目录。
- 拆分源文件到 `Sources/ClaudePersonas`；不保留上游“一份 Swift 文件”的组织方式。
- 应用更新只使用 `macfika/claude-personas` 的发布渠道和独立公钥，有本项目公钥时默认开启后台更新，可在设置中关闭。
- Homebrew cask 与应用源码放在同一个仓库，tap 需要显式仓库 URL。
- `./build.sh` 默认仅构建；`--install` 才执行本地安装和启动。
- 没有承诺 App Store 分发、Apple 公证、中文界面或 Windows/Linux 支持。

## 自动验证

在 macOS 和所需 Swift 工具链下运行：

```bash
./build.sh --no-install
./scripts/test.sh
lipo -archs build/ClaudePersonas.app/Contents/MacOS/ClaudePersonas
codesign --verify --deep --strict build/ClaudePersonas.app
```

预期架构输出包含 `arm64` 和 `x86_64`。`codesign --verify` 成功仅代表包的代码签名完整，不代表 Apple 公证或 Developer ID 身份认证。

## 人工验收清单

使用非关键测试账号与配置。记录 macOS 版本、CPU 架构、Claude Desktop 版本、Claude Personas 版本及结果。检查涉及运行状态的步骤时等待轮询刷新。

### 安装、默认数据与导入

- [ ] 从 Release ZIP 解压安装，首次打开的 Gatekeeper 提示与 README 一致；没有脚本自动删除 quarantine。
- [x] 从本项目 Homebrew tap 下载正式发布包，安装到临时应用目录，验证版本、架构与签名后卸载。
- [ ] 从已有旧版本执行 Homebrew upgrade，检查升级后的配置数据和运行行为。
- [ ] 默认配置能够打开原有 Claude 数据；首次导入符合语法的 zsh alias 和现有 Claude-* 目录。
- [ ] 创建新 Claude-* 目录后自动发现；移除的配置不会自动回到列表，且其数据保留。

### 多账号、登录与聚焦

- [ ] 创建 `Personal`、`Work`，分别登录两个真实测试账号；独立重启后各自仍保持正确账号。
- [ ] 分别测试 Google、SSO、电子邮件登录，确认回调进入发起登录的配置，其他配置不串号。
- [ ] 主动取消登录与退出工具后，确认 claude:// 处理程序恢复；重启工具后可再次登录。
- [ ] 点击运行中的配置只聚焦目标，前台名称/颜色、运行数量正确；退出一个配置不影响另一个。
- [ ] 全部开关与“Quit Profiles with Claude Personas”分别在开启和关闭状态符合设置。

### 配置、启动器及 CLI

- [ ] 修改名称、颜色、排序；运行中不移动数据目录，关闭后完成改名且旧 alias 仍可工作。
- [ ] 开启 App for Each Profile，测试 Spotlight、Launchpad、Add to Dock、自定义 App 名称和图标更新。
- [ ] 检查真实运行副本的官方签名仍有效，Dock、⌘-Tab、Mission Control 的图标对应账号。
- [ ] 在各配置 Terminal 中运行 Claude Code，独立登录并重启；确认 CLAUDE_CONFIG_DIR 对应配置。
- [ ] 复制配置后确认账号数据复制，随后退出副本账号不影响源配置；移除配置保留数据。
- [ ] 复制 MCP 时检查备份文件存在、其他配置键保留、同名服务器按预期覆盖；重启目标后实际可用。
- [ ] 开启两类快捷键、登录时启动及按配置自动启动，验证重启登录后的行为。

### Claude 更新及工具自更新

- [ ] 保持多个配置运行，让官方 Claude 完成真实更新；确认没有串到默认账号，原配置恢复。
- [ ] 主动退出的配置不会因恢复逻辑重新打开；正常使用默认账号的窗口不会被误关。
- [ ] 使用两个可信的项目测试版本验证签名更新，确认替换、面板关闭后重启及 Claude 窗口保留。
- [ ] 修改 ZIP、替换签名或使用错误公钥时拒绝安装，当前应用仍可启动。
- [ ] 断网、下载失败、目标目录不可写时不会破坏现有应用。

这些人工项是验收要求，并非本版本已经通过的测试结果。
