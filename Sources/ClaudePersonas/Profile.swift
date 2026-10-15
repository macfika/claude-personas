// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

struct Profile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var dir: String?   // nil = the default Claude profile, launched without --user-data-dir
    var color: Int?    // index into Palette.colors; nil until the first load assigns one
    var openAtLaunch: Bool?
    var codeDir: String?   // pinned Claude Code folder, kept when the data folder is renamed
    var appName: String?   // name of this profile's Dock app; nil = "Claude <name>"

    var isDefault: Bool { dir == nil }
    var initial: String { String(name.prefix(1)).uppercased() }
    var dockAppName: String {
        // Never plain "Claude": an app of that name could be taken for Claude itself.
        let custom = appName?.trimmingCharacters(in: .whitespaces) ?? ""
        if !custom.isEmpty, custom.lowercased() != "claude" { return custom }
        if name.lowercased() == "claude" { return isDefault ? "Claude Default" : "Claude Profile" }
        return name.lowercased().hasPrefix("claude") ? name : "Claude \(name)"
    }
    var folderURL: URL { dir.map { URL(fileURLWithPath: $0) } ?? supportDir.appendingPathComponent("Claude") }
    var tint: Color { Color(nsColor: nsTint) }
    var nsTint: NSColor { Palette.colors[colorIndex].color }
    var colorIndex: Int { ((color ?? 0) % Palette.colors.count + Palette.colors.count) % Palette.colors.count }
    private var key: String { name.lowercased().filter { $0.isLetter || $0.isNumber } }

    var shellAlias: String {
        let command = dir.map { "open -n -a Claude --args " + shellQuote("--user-data-dir=" + $0) } ?? "open -a Claude"
        return "alias " + shellQuote(key.isEmpty ? "claude-profile" : key) + "=" + shellQuote(command)
    }

    // Claude Code keeps its sign-in per config folder (and per Keychain entry on macOS),
    // so each profile gets ~/.claude-<folder suffix>. The default profile keeps ~/.claude.
    var codeConfigDir: String? {
        guard let dir else { return nil }
        if let codeDir { return codeDir }
        let suffix = URL(fileURLWithPath: dir).lastPathComponent.replacingOccurrences(of: "Claude-", with: "").lowercased()
        return FileManager.default.homeDirectoryForCurrentUser.path + "/.claude-" + suffix
    }

    var codeAlias: String {
        let command = codeConfigDir.map { "CLAUDE_CONFIG_DIR=" + shellQuote($0) + " claude" } ?? "claude"
        return "alias " + shellQuote("claude-" + (key.isEmpty ? "profile" : key)) + "=" + shellQuote(command)
    }
}
