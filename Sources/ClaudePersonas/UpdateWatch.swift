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
    static func installedVersion() -> String? {
        let app = realClaudeApp()
        // Read the plist directly: Bundle caches its info dictionary and would miss the update.
        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard let short = info?["CFBundleShortVersionString"] as? String else { return nil }
        return short + "+" + (info?["CFBundleVersion"] as? String ?? "")
    }

    // Profiles to reopen: stopped within 3 minutes of the version change, at least 4 s ago (so the new
    // bundle is in place), and only when Claude relaunched itself. That last check skips the case where
    // an update installs as someone quits Claude on purpose.
    // The default window is a stray when it started right after other profiles stopped for the update,
    // and the default itself did not stop around the update (so it was not open before).
    static func isStrayDefault(defaultLaunch: Date?, defaultStop: Date?, profileStops: [Date], updatedAt: Date) -> Bool {
        guard let launch = defaultLaunch else { return false }
        let near = profileStops.filter { abs($0.timeIntervalSince(updatedAt)) < 180 }
        guard let first = near.min(), let last = near.max() else { return false }
        if let defaultStop, abs(defaultStop.timeIntervalSince(updatedAt)) < 180 { return false }
        return launch >= first.addingTimeInterval(-2) && launch <= last.addingTimeInterval(30)
    }

    static func due(quitAt: [UUID: Date], updatedAt: Date, relaunched: Bool, now: Date) -> Set<UUID> {
        guard relaunched else { return [] }
        return Set(quitAt.filter { abs($0.value.timeIntervalSince(updatedAt)) < 180 && now.timeIntervalSince($0.value) >= 4 }.keys)
    }
}

// Reads a process's argv through sysctl, so no `ps` has to run.
