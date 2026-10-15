// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum MCP {
    static func configURL(_ p: Profile) -> URL { p.folderURL.appendingPathComponent("claude_desktop_config.json") }

    static func read(_ url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        return obj
    }

    static func servers(_ p: Profile) -> [String: Any] {
        ((try? read(configURL(p)))?["mcpServers"] as? [String: Any]) ?? [:]
    }

    // Adds the source servers to the target config; a server with the same name is replaced. Other keys stay.
    static func merge(_ target: [String: Any], adding servers: [String: Any]) -> [String: Any] {
        var out = target
        var current = target["mcpServers"] as? [String: Any] ?? [:]
        for (k, v) in servers { current[k] = v }
        out["mcpServers"] = current
        return out
    }

    @discardableResult
    static func copy(from source: Profile, to target: Profile) throws -> Int {
        let sourceConfig = try read(configURL(source))
        guard let servers = sourceConfig["mcpServers"] as? [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        let url = configURL(target)
        let existing = try read(url)
        guard existing["mcpServers"] == nil || existing["mcpServers"] is [String: Any] else { throw CocoaError(.fileReadCorruptFile) }
        let merged = merge(existing, adding: servers)
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd-HHmmss"
            try fm.copyItem(at: url, to: url.appendingPathExtension("bak-" + f.string(from: Date()) + "-" + UUID().uuidString))
        } else {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        let data = try JSONSerialization.data(withJSONObject: merged, options: [.prettyPrinted, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
        return servers.count
    }
}
