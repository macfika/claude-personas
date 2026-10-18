// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Updater {
    static let latestURL = URL(string: "https://api.github.com/repos/macfika/claude-personas/releases/latest")!
    @MainActor static var relaunching = false

    struct Release { let version: String; let zip: URL; let signature: URL }

    static var currentVersion: String { ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_FAKE_VERSION"] ?? appVersion }

    // The GUI update lifecycle belongs to Sparkle; Homebrew copies never start it.
    @MainActor static func start() { UpdateController.shared.start() }

    static func latest() async throws -> Release? {
        var req = URLRequest(url: latestURL, timeoutInterval: 30)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("ClaudePersonas/\(appVersion)", forHTTPHeaderField: "User-Agent")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]],
              let asset = assets.first(where: { ($0["name"] as? String) == "ClaudePersonas-\(tag.hasPrefix("v") ? String(tag.dropFirst()) : tag).zip" }),
              let name = asset["name"] as? String,
              let sigAsset = assets.first(where: { $0["name"] as? String == name + ".sig" }),
              let url = trusted(asset["browser_download_url"]), let sigURL = trusted(sigAsset["browser_download_url"])
        else { return nil }
        return Release(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, zip: url, signature: sigURL)
    }

    static func trusted(_ any: Any?) -> URL? {
        guard let s = any as? String, let url = URL(string: s), url.scheme == "https", url.host == "github.com",
              url.path.hasPrefix("/macfika/claude-personas/releases/download/") else { return nil }
        return url
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    static func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 { throw UpdateError.command(tool) }
    }

}
