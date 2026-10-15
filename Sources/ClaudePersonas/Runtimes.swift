// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Runtimes {
    static var folder: URL {
        if isCLI, let root = ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_TEST_ROOT"], !root.isEmpty {
            return URL(fileURLWithPath: root).appendingPathComponent("Runtimes.noindex")
        }
        return supportDir.appendingPathComponent("ClaudePersonas/Runtimes.noindex")
    }
    static let format = 3   // a stamp from another format means the copy is rebuilt from scratch

    // folder/<profile id>/<app name>.app: macOS names the running app after the bundle's file name.
    static func dir(_ id: UUID) -> URL { folder.appendingPathComponent(id.uuidString) }
    static func stampURL(_ id: UUID) -> URL { dir(id).appendingPathComponent("stamp") }
    static func target(_ p: Profile) -> URL { dir(p.id).appendingPathComponent(Launchers.fileName(p.dockAppName)) }
    static func current(_ id: UUID) -> URL? {
        ((try? FileManager.default.contentsOfDirectory(at: dir(id), includingPropertiesForKeys: nil)) ?? [])
            .first { $0.pathExtension == "app" }
    }
    static func exists(_ id: UUID) -> Bool { current(id) != nil }

    // The profile id of a copy's bundle URL, or nil for any other Claude.
    static func owner(of app: URL) -> UUID? {
        let parent = app.standardizedFileURL.deletingLastPathComponent()
        guard parent.deletingLastPathComponent().standardizedFileURL.path == folder.standardizedFileURL.path else { return nil }
        return UUID(uuidString: parent.lastPathComponent)
    }

    static func version(_ app: URL) -> String? {
        NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))?["CFBundleShortVersionString"] as? String
    }

    static func stamp(_ p: Profile, version: String) -> String {
        "\(format)|\(version)|\(p.dockAppName)|\(p.initial)|\(p.color ?? 0)"
    }

    static func isRunning(_ app: URL) -> Bool {
        let path = app.standardizedFileURL.path
        return NSWorkspace.shared.runningApplications.contains {
            !$0.isTerminated && $0.bundleURL?.standardizedFileURL.path == path
        }
    }

    // The profile's own Claude, made or refreshed as needed, or nil when it can't be (not APFS, no Claude).
    // Never touches a copy that is running.
    static func ensure(_ p: Profile, from claude: URL, running: (URL) -> Bool = isRunning) -> URL? {
        let fm = FileManager.default
        let want = target(p)
        guard let source = version(claude) else { return current(p.id) }
        if var rt = current(p.id) {
            if running(rt) {
                // Only the icon can change under a running copy: it sits outside the bundle's code.
                let stamped = (try? String(contentsOf: stampURL(p.id), encoding: .utf8)) ?? ""
                let current = version(rt) ?? ""
                if stamped.hasPrefix("\(format)|"), stamped != stamp(p, version: current) {
                    applyLook(p, to: rt, version: current, register: false)
                }
                return rt
            }
            if rt.lastPathComponent != want.lastPathComponent, (try? fm.moveItem(at: rt, to: want)) != nil { rt = want }
            let current = version(rt) ?? ""
            let stamped = (try? String(contentsOf: stampURL(p.id), encoding: .utf8)) ?? ""
            if stamped.hasPrefix("\(format)|"), current == source || Updater.isNewer(current, than: source) {
                if stamped == stamp(p, version: current) && hasLook(rt) { return rt }
                applyLook(p, to: rt, version: current)
                return rt
            }
            try? fm.removeItem(at: rt)
        }
        try? fm.createDirectory(at: dir(p.id), withIntermediateDirectories: true)
        // clonefile copies the whole bundle as one APFS clone; it fails rather than copy on other volumes.
        guard clonefile(claude.path, want.path, 0) == 0 else { return nil }
        applyLook(p, to: want, version: source)
        return want
    }

    // A folder's custom icon lives in an "Icon\r" file at its root, outside the sealed Contents.
    static func hasLook(_ app: URL) -> Bool {
        FileManager.default.fileExists(atPath: app.appendingPathComponent("Icon\r").path)
    }

    static func applyLook(_ p: Profile, to app: URL, version: String, register: Bool = true) {
        let fm = FileManager.default
        let ok = NSWorkspace.shared.setIcon(AppIcon.profile(1024, color: p.nsTint, letter: p.initial), forFile: app.path, options: [])
        Log.write("profile copy \(app.lastPathComponent): icon \(ok ? "set" : "FAILED"), Claude \(version)")
        try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: app.path)
        if register && !isCLI { LSRegisterURL(app as CFURL, true) }
        try? Data(stamp(p, version: version).utf8).write(to: stampURL(p.id))
    }

    // Deletes the copies of profiles that are gone (or of all, with profile apps off), unless running.
    static func prune(keeping ids: Set<UUID>) {
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: folder.path)) ?? [] {
            guard let id = UUID(uuidString: name), !ids.contains(id) else { continue }
            if let rt = current(id), isRunning(rt) { continue }
            try? fm.removeItem(at: dir(id))
        }
    }
}


// One small app per profile in ~/Applications/ClaudePersonas Launchers, named and colored after the profile,
// so the Dock, Spotlight and Launchpad can tell accounts apart. Its executable is a shell script that asks
// ClaudePersonas to open the profile (claude-personas://open?profile=<id>) and opens Claude directly when
// ClaudePersonas is gone. Claude's own window keeps Claude's name and icon: editing Claude.app's Info.plist
// breaks its signature and macOS kills it at launch, and a copy of the bundle keeps Claude's icon (tested
// 2026-10-10 on Claude 1.x, macOS 27).
