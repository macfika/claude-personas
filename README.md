# Claude Personas

**English** | [简体中文](README.zh-CN.md)

Manage multiple Claude Desktop accounts from your Mac menu bar and switch between work, personal, and other profiles.

Requires **macOS 15 or later** and the official [Claude Desktop](https://claude.ai/download) app. Supports Apple silicon and Intel Macs.

## Install (DMG recommended)

[**Download Claude Personas DMG**](https://github.com/macfika/claude-personas/releases/download/v0.3.3/ClaudePersonas-0.3.3.dmg) · [View the latest release](https://github.com/macfika/claude-personas/releases/latest)

1. Download and double-click the DMG.
2. Follow the arrow and drag **Claude Personas** into the **Applications** folder on the right.
3. Wait for copying to finish, open Claude Personas from Applications, then eject the installation disk.

DMG installation is recommended. The app checks for updates automatically, and you can also choose **Check for Updates…** in Settings. You do not need to download a new installer for every update. Open the app from Applications rather than running it directly from the installation disk.

## Get started

1. Click the asterisk icon in the menu bar. The default profile uses your existing Claude account.
2. Choose **New Profile**, enter a name such as `Work`, then sign in to another account.
3. Click a profile to open or focus its window. The switch at the top opens or quits all profiles.
4. Right-click a profile to rename it, change its order or color, open its data folder, or remove it from the list.

New profiles require a separate sign-in. **Duplicate as New Profile…** copies the original profile's sign-in state, chat data, and settings, so the copy initially belongs to the same account.

## Features

- Run multiple Claude accounts at the same time, each with its own data folder and status indicator.
- Customize profile names, colors, and startup preferences, and create separate Dock and app launchers.
- Duplicate profiles, copy MCP server settings, and use separate configurations for Claude Code.
- Enable menu bar shortcuts, profile shortcuts, and launch at login.
- Use Simplified Chinese, Traditional Chinese, Japanese, Korean, or English. The app follows your system language by default; change it in **Settings → Language**.

Claude Code features require the `claude` command-line tool to be installed and signed in separately.

## Updates

**DMG installations:** Automatic update checks are enabled by default. Follow the prompts in the app to update. You can turn off automatic checks in Settings or choose **Check for Updates…** at any time. If you previously disabled automatic checks, reinstalling preserves that choice.

**Homebrew installations:** Choose **Update with Homebrew…** in the app, or run:

```bash
brew update
brew upgrade --cask macfika/claude-personas/claude-personas
```

## Install with Homebrew (optional)

If you prefer Homebrew, install from the terminal:

```bash
brew tap macfika/claude-personas https://github.com/macfika/claude-personas
brew install --cask macfika/claude-personas/claude-personas
```

### Switch from Homebrew to DMG

Quit Claude Personas, then perform a normal uninstall:

```bash
brew uninstall --cask macfika/claude-personas/claude-personas
```

Install using the DMG steps above. **Your settings, profile list, and account data are preserved**, and you can then use in-app automatic updates. Do not delete app data or use cleanup tools to erase settings. Launch at login and system permissions may need to be enabled again.

## Data and privacy

Removing a profile from the list does not delete its data. The default account's data is stored in `~/Library/Application Support/Claude`; other profiles typically use sibling folders named `Claude-<name>`. Open a profile's data folder from its menu to check its contents before deleting anything.

The app has no analytics. To manage profiles and sign-ins, it reads relevant processes, configuration files, supported shell aliases, and Claude sign-in logs. Update checks connect to GitHub to retrieve updates. Duplicating a profile also copies its sign-in state and chat data, so check the destination profile.

## Help and contributing

Report problems in an [Issue](https://github.com/macfika/claude-personas/issues), including your macOS version, app version, and steps to reproduce the problem. Logs may contain personal paths; review them before sharing.

Developers can refer to the [contributing guide](CONTRIBUTING.md).

## License and credits

[Apache License 2.0](LICENSE). Based on [MultiClaude](https://github.com/QuentinCar0n/multiclaude). See [NOTICE](NOTICE) for credits and third-party license information.

Claude is a trademark of Anthropic. This is an independent project and is not affiliated with, sponsored by, or endorsed by Anthropic.
