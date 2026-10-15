// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Launchers {
    static let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/ClaudePersonas Launchers")
    static let idPrefix = "com.macfika.claude-personas.launcher."
    static let format = 3   // bump when the bundle layout, the script or the icon changes, so every app is rewritten

    struct SyncResult {
        var moved: [(from: URL, to: URL)] = []
        var removed: [URL] = []
        var rewritten: [URL] = []   // existing apps whose name, color or folder changed
        var failed: [String] = []
    }

    // "Claude Work" -> "Claude Work.app", with the characters Finder can't show in a name replaced.
    static func fileName(_ name: String) -> String {
        let safe = name.unicodeScalars.filter { !CharacterSet.controlCharacters.contains($0) }.map(String.init).joined()
        let clean = safe.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return (clean.isEmpty ? "Claude" : clean) + ".app"
    }

    static func script(for p: Profile) -> String {
        let rt = shellQuote(Runtimes.dir(p.id).path), real = shellQuote(realClaudeApp().path)
        let fallback = "app=$(ls -d \(rt)/*.app 2>/dev/null | head -n 1); [ -d \"$app\" ] || app=\(real)\n"
            + (p.dir.map { "exec /usr/bin/open -n -a \"$app\" --args \(shellQuote("--user-data-dir=" + $0))" } ?? "exec /usr/bin/open -a \"$app\"")
        return """
        #!/bin/sh
        # Made by Claude Personas. This launcher is managed automatically; edits are lost.
        /usr/bin/open -g "claude-personas://open?profile=\(p.id.uuidString)" 2>/dev/null && exit 0
        \(fallback)

        """
    }

    // Everything that shows in the app; a change in any of it rewrites the app.
    static func stamp(for p: Profile, name: String) -> String {
        "\(format)|\(name)|\(p.initial)|\(p.color ?? 0)|\(p.dir ?? "")|\(p.name)"
    }

    static func info(for p: Profile, name: String) -> [String: Any] {
        [
            "CFBundleName": name,
            "CFBundleDisplayName": name,
            "CFBundleIdentifier": idPrefix + p.id.uuidString.lowercased(),
            "CFBundleExecutable": "launch",
            "CFBundleIconFile": "icon",
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "\(format)",
            "LSUIElement": true,   // the script quits at once; no Dock bounce of its own
            "MCProfileID": p.id.uuidString,
            "MCStamp": stamp(for: p, name: name),
        ]
    }

    static func readInfo(_ app: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any]
    }

    // The profile apps in `folder`, by profile. Other apps a user puts there are left alone.
    static func installed(in folder: URL) -> [UUID: URL] {
        let items = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        var out: [UUID: URL] = [:]
        for app in items where app.pathExtension == "app" {
            guard let info = readInfo(app), (info["CFBundleIdentifier"] as? String)?.hasPrefix(idPrefix) == true,
                  let id = (info["MCProfileID"] as? String).flatMap(UUID.init(uuidString:)) else { continue }
            out[id] = app
        }
        return out
    }

    // Builds the app next to its destination, then swaps it in, so a half-written app never shows up.
    static func write(_ p: Profile, name: String, to dest: URL) throws {
        let fm = FileManager.default
        let tmp = dest.deletingLastPathComponent().appendingPathComponent(".\(p.id.uuidString).tmp.app")
        try? fm.removeItem(at: tmp)
        let contents = tmp.appendingPathComponent("Contents")
        try fm.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try fm.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        let plist = try PropertyListSerialization.data(fromPropertyList: info(for: p, name: name), format: .xml, options: 0)
        try plist.write(to: contents.appendingPathComponent("Info.plist"))
        try Data("APPL????".utf8).write(to: contents.appendingPathComponent("PkgInfo"))
        let exe = contents.appendingPathComponent("MacOS/launch")
        try Data(script(for: p).utf8).write(to: exe)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: exe.path)
        guard let icon = AppIcon.icns({ AppIcon.profile($0, color: p.nsTint, letter: p.initial) }) else { throw CocoaError(.fileWriteUnknown) }
        try icon.write(to: contents.appendingPathComponent("Resources/icon.icns"))
        if fm.fileExists(atPath: dest.path) {
            _ = try fm.replaceItemAt(dest, withItemAt: tmp)
        } else {
            try fm.moveItem(at: tmp, to: dest)
        }
        // New modification date + re-registration, so Finder, the Dock and Spotlight drop the old icon and name.
        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: dest.path)
        if !isCLI { LSRegisterURL(dest as CFURL, true) }
    }

    // Makes `folder` hold exactly one up-to-date app per profile in `profiles`.
    static func sync(_ profiles: [Profile], in folder: URL) -> SyncResult {
        let fm = FileManager.default
        var result = SyncResult()
        var have = installed(in: folder)
        for (id, url) in have where !profiles.contains(where: { $0.id == id }) {
            if (try? fm.removeItem(at: url)) != nil { result.removed.append(url) }
            have[id] = nil
        }
        guard !profiles.isEmpty else { return result }
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        var taken: Set<String> = ["claude.app"]   // never shadow Claude itself
        for p in profiles {
            // Two profiles can't share a file name; the later one gets a number.
            var name = p.dockAppName, n = 2
            while taken.contains(fileName(name).lowercased()) { name = "\(p.dockAppName) \(n)"; n += 1 }
            taken.insert(fileName(name).lowercased())
            let dest = folder.appendingPathComponent(fileName(name))
            if let current = have[p.id] {
                let same = current.standardizedFileURL == dest.standardizedFileURL
                if same, readInfo(current)?["MCStamp"] as? String == stamp(for: p, name: name) { continue }
                if !same {
                    // Free the new name first if another profile's old app still sits there.
                    if fm.fileExists(atPath: dest.path) && current.lastPathComponent.lowercased() != dest.lastPathComponent.lowercased() {
                        result.failed.append(p.name); continue
                    }
                    do { try fm.moveItem(at: current, to: dest); result.moved.append((current, dest)) }
                    catch { result.failed.append(p.name); continue }
                }
            } else if fm.fileExists(atPath: dest.path) {
                result.failed.append(p.name); continue   // a file ClaudePersonas didn't make; leave it
            }
            do {
                try write(p, name: name, to: dest)
                if have[p.id] != nil { result.rewritten.append(dest) }
            } catch { result.failed.append(p.name) }
        }
        return result
    }
}

// The Dock's pinned apps live in com.apple.dock's persistent-apps. ClaudePersonas only touches entries
// for its own profile apps, and only when the user pins one or one of them moves or goes away.
