// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Seed {
    // First run: the default profile, the Claude aliases in ~/.zshrc, then any other Claude-* folder.
    static func profiles() -> [Profile] {
        var list = [Profile(name: "Claude", dir: nil)]
        var seen: Set<String> = [Folders.canonical(supportDir.appendingPathComponent("Claude").path)]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let rc = (try? String(contentsOfFile: home + "/.zshrc", encoding: .utf8)) ?? ""
        let re = try! NSRegularExpression(pattern: #"alias\s+(\w+)=['"]open -n -a "?Claude"? --args --user-data-dir="?([^"']+)"?['"]"#)
        for m in re.matches(in: rc, range: NSRange(rc.startIndex..., in: rc)) {
            guard let n = Range(m.range(at: 1), in: rc), let d = Range(m.range(at: 2), in: rc) else { continue }
            let dir = String(rc[d]).replacingOccurrences(of: "$HOME", with: home)
            let canonical = Folders.canonical(dir)
            guard !seen.contains(canonical) else { continue }
            list.append(Profile(name: String(rc[n]).capitalized, dir: dir))
            seen.insert(canonical)
        }
        for dir in Folders.candidates(in: supportDir.path) {
            let canonical = Folders.canonical(dir)
            guard !seen.contains(canonical) else { continue }
            let name = String(URL(fileURLWithPath: dir).lastPathComponent.dropFirst(7))
            list.append(Profile(name: name, dir: dir))
            seen.insert(canonical)
        }
        return list
    }
}

// MARK: - Settings
