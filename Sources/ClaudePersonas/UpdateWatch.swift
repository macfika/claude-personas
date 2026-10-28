// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum UpdateWatch {
    // NSRunningApplication resolves launchDate lazily. An unread launchDate can become nil once
    // the process exits, so retain its value while the process is still observable.
    struct ProcessSnapshot {
        let pid: pid_t
        let launchedAt: Date

        init(app: NSRunningApplication, observedAt: Date) {
            pid = app.processIdentifier
            launchedAt = app.launchDate ?? observedAt
        }
    }

    static func installedVersion() -> String? {
        let app = realClaudeApp()
        // Read the plist directly: Bundle caches its info dictionary and would miss the update.
        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard let short = info?["CFBundleShortVersionString"] as? String else { return nil }
        return short + "+" + (info?["CFBundleVersion"] as? String ?? "")
    }

    // Claude can quit for an update without replacing the bundle or relaunching the default.
    // Accept only a fresh record from this process lifetime, never a previous launch's cleanup.
    static func quitForUpdate(config: URL, launchedAt: Date?, stoppedAt: Date) -> Bool? {
        guard let data = try? Data(contentsOf: config),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cleanup = object["lastQuitCleanup"] as? [String: Any],
              let forUpdate = cleanup["for_update"] as? Bool,
              let epoch = cleanup["quit_epoch_ms"] as? Double,
              let launchedAt else { return nil }
        let quit = Date(timeIntervalSince1970: epoch / 1000)
        guard quit >= launchedAt && abs(stoppedAt.timeIntervalSince(quit)) < 30 else { return nil }
        return forUpdate
    }

    static func due(quitAt: [UUID: Date], updatedAt: Date, relaunched: Bool, now: Date, updateExits: Set<UUID> = []) -> Set<UUID> {
        return Set(quitAt.filter { id, stopped in
            let age = now.timeIntervalSince(stopped)
            if updateExits.contains(id) { return age >= 15 && age < 300 }
            return relaunched && abs(stopped.timeIntervalSince(updatedAt)) < 180 && age >= 4
        }.keys)
    }
}

// Reads a process's argv through sysctl, so no `ps` has to run.
