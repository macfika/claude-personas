// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import Foundation

/// Ownership of this particular app copy, rather than the machine's installed casks.
enum InstallationChannel: Equatable, Sendable {
    case homebrew
    case manual
    case development
    /// Metadata points at this copy but cannot establish a healthy Homebrew installation.
    case uncertainHomebrew

    var isHomebrew: Bool { self == .homebrew || self == .uncertainHomebrew }
    var allowsSelfUpdates: Bool { self == .manual }

    static func detect(
        appURL: URL = Bundle.main.bundleURL,
        prefixes: [URL] = [URL(fileURLWithPath: "/opt/homebrew"), URL(fileURLWithPath: "/usr/local")]
    ) -> Self {
        let fm = FileManager.default
        let app = appURL.standardizedFileURL
        guard app.isFileURL, app.lastPathComponent == "ClaudePersonas.app",
              isDirectory(app) else { return .development }
        let canonicalApp = app.resolvingSymlinksInPath()
        var uncertain = false
        for prefix in prefixes {
            let cask = prefix.appendingPathComponent("Caskroom/claude-personas", isDirectory: true)
            guard let entries = try? fm.contentsOfDirectory(at: cask, includingPropertiesForKeys: nil) else { continue }
            // Cask's app artifact is normally a symlink to the installed /Applications copy.
            // An empty Caskroom or another installed copy is not evidence about this app.
            for version in entries where !version.lastPathComponent.hasPrefix(".") && isDirectory(version) {
                let artifact = version.appendingPathComponent("ClaudePersonas.app", isDirectory: true)
                if isDirectory(artifact), artifact.resolvingSymlinksInPath() == canonicalApp { return .homebrew }
            }
            let metadata = cask.appendingPathComponent(".metadata", isDirectory: true)
            guard let config = json(metadata.appendingPathComponent("config.json")),
                  let appDirectory = configuredAppDirectory(config) else { continue }
            let destination = URL(fileURLWithPath: appDirectory, isDirectory: true)
                .appendingPathComponent("ClaudePersonas.app", isDirectory: true)
            guard destination.standardizedFileURL.resolvingSymlinksInPath() == canonicalApp else { continue }
            let receiptURL = metadata.appendingPathComponent("INSTALL_RECEIPT.json")
            guard fm.fileExists(atPath: receiptURL.path) else {
                uncertain = true
                continue
            }
            // Copied artifacts do not share an inode or path with their source in Caskroom.
            // Require a cask receipt, exact artifact name and an extant installed version.
            if let receipt = json(receiptURL),
               let source = receipt["source"] as? [String: Any],
               let version = source["version"] as? String,
               !version.isEmpty, version != ".", version != "..", !version.contains("/"),
               let brewVersion = receipt["homebrew_version"] as? String, !brewVersion.isEmpty,
               let artifacts = receipt["uninstall_artifacts"] as? [[String: Any]],
               artifacts.contains(where: { ($0["app"] as? [String])?.contains("ClaudePersonas.app") == true }),
               isDirectory(cask.appendingPathComponent(version, isDirectory: true)) {
                return .homebrew
            }
            uncertain = true
        }
        if uncertain { return .uncertainHomebrew }
        // SwiftPM's bare executable and the repository build output must never replace themselves.
        if app.pathComponents.contains(".build") || app.deletingLastPathComponent().lastPathComponent == "build" {
            return .development
        }
        return .manual
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var directory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) && directory.boolValue
    }

    private static func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func configuredAppDirectory(_ config: [String: Any]) -> String? {
        let explicit = config["explicit"] as? [String: Any]
        let defaults = config["default"] as? [String: Any]
        guard let path = (explicit?["appdir"] ?? defaults?["appdir"]) as? String,
              path.hasPrefix("/"), !path.contains("\0") else { return nil }
        return path
    }
}
