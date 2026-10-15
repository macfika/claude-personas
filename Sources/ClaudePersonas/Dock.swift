// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

@MainActor
enum Dock {
    static let domain = "com.apple.dock" as CFString

    static func entries() -> [[String: Any]] {
        CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]] ?? []
    }

    static func path(of entry: [String: Any]) -> String? {
        guard let tile = entry["tile-data"] as? [String: Any], let file = tile["file-data"] as? [String: Any],
              let s = file["_CFURLString"] as? String else { return nil }
        return (URL(string: s)?.path ?? s).replacingOccurrences(of: "/$", with: "", options: .regularExpression)
    }

    static func entry(for app: URL) -> [String: Any] {
        ["tile-type": "file-tile",
         "tile-data": ["file-label": app.deletingPathExtension().lastPathComponent,
                       "file-data": ["_CFURLString": app.absoluteString, "_CFURLStringType": 15]]]
    }

    static func contains(_ app: URL) -> Bool {
        entries().contains { path(of: $0) == app.standardizedFileURL.path }
    }

    private static func write(_ list: [[String: Any]]) {
        CFPreferencesSetAppValue("persistent-apps" as CFString, list as CFArray, domain)
        CFPreferencesAppSynchronize(domain)
        // The Dock reads its tiles at start only.
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        p.arguments = ["Dock"]
        try? p.run()
    }

    @discardableResult
    static func add(_ app: URL) -> Bool {
        if contains(app) { return true }
        var list = entries()
        list.append(entry(for: app))
        write(list)
        return true
    }

    // Points moved apps' tiles at their new path and drops the tiles of removed apps.
    // The Dock keeps a pinned app's old icon even across restarts, so a tile in `refresh` is taken off
    // the Dock and put back in the same place a moment later, which makes the Dock read the new icon.
    static func update(moved: [(from: URL, to: URL)], removed: [URL], refresh: [URL] = []) {
        let gone = Set(removed.map(\.standardizedFileURL.path))
        let moves = Dictionary(moved.map { ($0.from.standardizedFileURL.path, $0.to) }, uniquingKeysWith: { a, _ in a })
        let redo = Set(refresh.map(\.standardizedFileURL.path))
        var changed = false, refreshing = false
        var list: [[String: Any]] = [], without: [[String: Any]] = []
        for e in entries() {
            guard let p = path(of: e) else { list.append(e); without.append(e); continue }
            if gone.contains(p) { changed = true; continue }
            let to = moves[p]
            let path = to?.standardizedFileURL.path ?? p
            // A fresh entry, without the Dock's GUID, so it doesn't reuse the cached icon.
            let final = to != nil || redo.contains(path) ? entry(for: URL(fileURLWithPath: path)) : e
            if to != nil { changed = true }
            list.append(final)
            if redo.contains(path) { refreshing = true } else { without.append(final) }
        }
        guard refreshing else { if changed { write(list) }; return }
        write(without)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { write(list) }   // once the Dock is back up
    }
}

// MARK: - Panel views
