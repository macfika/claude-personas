// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import Foundation

enum InstallationChannelTests {
    static func run() -> Bool {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("claude-personas-channel-tests-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        var ok = true
        func check(_ name: String, _ test: () throws -> Bool) {
            do {
                let passed = try test()
                print(passed ? "PASS" : "FAIL", name)
                ok = ok && passed
            } catch { print("FAIL", name, error); ok = false }
        }
        func directory(_ url: URL) throws { try fm.createDirectory(at: url, withIntermediateDirectories: true) }
        func fixture(_ name: String) throws -> (URL, URL, URL) {
            let folder = root.appendingPathComponent(name)
            let prefix = folder.appendingPathComponent("brew")
            let app = folder.appendingPathComponent("Applications/ClaudePersonas.app")
            let cask = prefix.appendingPathComponent("Caskroom/claude-personas")
            try directory(app)
            try directory(cask)
            return (prefix, app, cask)
        }
        func write(_ object: [String: Any], _ url: URL) throws {
            try directory(url.deletingLastPathComponent())
            try JSONSerialization.data(withJSONObject: object).write(to: url)
        }
        func metadata(_ cask: URL, appdir: URL, explicit: Bool = false) throws {
            try write(["default": ["appdir": explicit ? "/Applications" : appdir.path],
                       "explicit": explicit ? ["appdir": appdir.path] : [:]], cask.appendingPathComponent(".metadata/config.json"))
            try write(["homebrew_version": "4.6.0", "source": ["version": "0.2.1"],
                       "uninstall_artifacts": [["app": ["ClaudePersonas.app"]]]], cask.appendingPathComponent(".metadata/INSTALL_RECEIPT.json"))
            try directory(cask.appendingPathComponent("0.2.1"))
        }
        for name in ["opt/homebrew", "usr/local", "custom/brew"] {
            check("Homebrew symlink under \(name)") {
                let folder = root.appendingPathComponent(name)
                let prefix = folder.appendingPathComponent(name)
                let app = folder.appendingPathComponent("Applications/ClaudePersonas.app")
                let version = prefix.appendingPathComponent("Caskroom/claude-personas/0.2.1")
                try directory(app)
                try directory(version)
                try fm.createSymbolicLink(at: version.appendingPathComponent("ClaudePersonas.app"), withDestinationURL: app)
                return InstallationChannel.detect(appURL: app, prefixes: [prefix]) == .homebrew
            }
        }
        check("empty Caskroom leaves manual copy unmanaged") {
            let (prefix, app, _) = try fixture("empty")
            return InstallationChannel.detect(appURL: app, prefixes: [prefix]) == .manual
        }
        check("Homebrew install does not claim separate manual copy") {
            let (prefix, app, cask) = try fixture("separate")
            try metadata(cask, appdir: app.deletingLastPathComponent())
            try fm.createSymbolicLink(at: cask.appendingPathComponent("0.2.1/ClaudePersonas.app"), withDestinationURL: app)
            let manual = root.appendingPathComponent("Downloads/ClaudePersonas.app")
            try directory(manual)
            return InstallationChannel.detect(appURL: manual, prefixes: [prefix]) == .manual
        }
        for explicit in [false, true] {
            check("copied artifact respects \(explicit ? "explicit" : "default") appdir") {
                let (prefix, _, cask) = try fixture("copied-\(explicit)")
                let appdir = root.appendingPathComponent("custom applications \(explicit)")
                let app = appdir.appendingPathComponent("ClaudePersonas.app")
                try directory(app)
                try metadata(cask, appdir: appdir, explicit: explicit)
                try directory(cask.appendingPathComponent("0.2.1/ClaudePersonas.app"))
                return InstallationChannel.detect(appURL: app, prefixes: [prefix]) == .homebrew
            }
        }
        check("symlinked application directory is canonicalized") {
            let (prefix, app, cask) = try fixture("canonical")
            try metadata(cask, appdir: app.deletingLastPathComponent())
            let alias = root.appendingPathComponent("Alias")
            try fm.createSymbolicLink(at: alias, withDestinationURL: app.deletingLastPathComponent())
            return InstallationChannel.detect(appURL: alias.appendingPathComponent("ClaudePersonas.app"), prefixes: [prefix]) == .homebrew
        }
        check("broken receipt for matching copy disables self updates") {
            let (prefix, app, cask) = try fixture("broken")
            try metadata(cask, appdir: app.deletingLastPathComponent())
            try Data("invalid".utf8).write(to: cask.appendingPathComponent(".metadata/INSTALL_RECEIPT.json"))
            let channel = InstallationChannel.detect(appURL: app, prefixes: [prefix])
            return channel == .uncertainHomebrew && channel.isHomebrew && !channel.allowsSelfUpdates
        }
        check("missing receipt for configured copy disables self updates") {
            let (prefix, app, cask) = try fixture("missing-receipt")
            try metadata(cask, appdir: app.deletingLastPathComponent())
            try fm.removeItem(at: cask.appendingPathComponent(".metadata/INSTALL_RECEIPT.json"))
            return InstallationChannel.detect(appURL: app, prefixes: [prefix]) == .uncertainHomebrew
        }
        check("dangling artifact cannot claim unrelated manual app") {
            let (prefix, app, cask) = try fixture("dangling")
            try directory(cask.appendingPathComponent("0.2.1"))
            try fm.createSymbolicLink(at: cask.appendingPathComponent("0.2.1/ClaudePersonas.app"),
                                      withDestinationURL: root.appendingPathComponent("removed/ClaudePersonas.app"))
            return InstallationChannel.detect(appURL: app, prefixes: [prefix]) == .manual
        }
        check("missing installed version is uncertain") {
            let (prefix, app, cask) = try fixture("missing-version")
            try metadata(cask, appdir: app.deletingLastPathComponent())
            try fm.removeItem(at: cask.appendingPathComponent("0.2.1"))
            return InstallationChannel.detect(appURL: app, prefixes: [prefix]) == .uncertainHomebrew
        }
        check("broken receipt pointing elsewhere does not claim manual app") {
            let (prefix, app, cask) = try fixture("other-broken")
            try metadata(cask, appdir: root.appendingPathComponent("elsewhere"))
            try Data("invalid".utf8).write(to: cask.appendingPathComponent(".metadata/INSTALL_RECEIPT.json"))
            return InstallationChannel.detect(appURL: app, prefixes: [prefix]) == .manual
        }
        check("receipt must contain exact app artifact") {
            let (prefix, app, cask) = try fixture("wrong-artifact")
            try metadata(cask, appdir: app.deletingLastPathComponent())
            try write(["homebrew_version": "4.6", "source": ["version": "0.2.1"],
                       "uninstall_artifacts": [["app": ["Other.app"]]]], cask.appendingPathComponent(".metadata/INSTALL_RECEIPT.json"))
            return InstallationChannel.detect(appURL: app, prefixes: [prefix]) == .uncertainHomebrew
        }
        check("similar name is not a release app") {
            let (prefix, app, _) = try fixture("similar")
            let other = app.deletingLastPathComponent().appendingPathComponent("ClaudePersonas.app.backup")
            try directory(other)
            return InstallationChannel.detect(appURL: other, prefixes: [prefix]) == .development
        }
        check("bare executable is development") {
            let url = root.appendingPathComponent(".build/debug/ClaudePersonas")
            try directory(url.deletingLastPathComponent())
            try Data().write(to: url)
            return InstallationChannel.detect(appURL: url, prefixes: []) == .development
        }
        check("repo build app cannot self update") {
            let app = root.appendingPathComponent("repo/build/ClaudePersonas.app")
            try directory(app)
            let channel = InstallationChannel.detect(appURL: app, prefixes: [])
            return channel == .development && !channel.allowsSelfUpdates
        }
        check("manual app can self update") {
            let (_, app, _) = try fixture("manual")
            return InstallationChannel.detect(appURL: app, prefixes: []).allowsSelfUpdates
        }
        check("nonexistent app is development") {
            InstallationChannel.detect(appURL: root.appendingPathComponent("missing/ClaudePersonas.app"), prefixes: []) == .development
        }
        return ok
    }
}
