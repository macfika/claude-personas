// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Launch {
    // `open -a` brings forward whichever Claude is already running, which may be another account.
    // With any instance up, the default account needs -n to start its own process.
    // `app` is a full path (Claude.app or the profile's own copy), so a profile app named like Claude
    // can never be opened in its place.
    static func openArgs(app: String, dir: String?, anyClaudeRunning: Bool) -> [String] {
        if let dir { return ["-n", "-a", app, "--args", "--user-data-dir=\(dir)"] }
        return anyClaudeRunning ? ["-n", "-a", app] : ["-a", app]
    }
}
