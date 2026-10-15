// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum SignInLog {
    static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Claude/main.log")

    static func size() -> UInt64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.uint64Value ?? 0
    }

    static func read(from offset: UInt64) -> ([String], UInt64) {
        guard let h = try? FileHandle(forReadingFrom: url) else { return ([], offset) }
        defer { try? h.close() }
        let end = (try? h.seekToEnd()) ?? offset
        let start = end < offset ? 0 : offset   // the log rotated
        try? h.seek(toOffset: start)
        let data = (try? h.readToEnd()) ?? Data()
        return (String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init), end)
    }

    // Done once the browser sign-in has come back: the claude:// login link was handled, or the
    // account reports logged in after the browser step (a plain "logged in" at launch is not enough,
    // Claude logs it right before bouncing a stale session to /logout).
    static func scan(_ lines: [String], sawBrowser: Bool) -> (sawBrowser: Bool, done: Bool) {
        var saw = sawBrowser
        for l in lines {
            if l.contains("[Auth] Using system browser") || l.contains("[Auth] Starting ASWebAuth") { saw = true }
            if l.contains("[Auth] ASWebAuth completed") { return (true, true) }
            if l.contains("claudeURLHandler: login") { return (true, true) }
            if saw && l.contains("account active and logged in") { return (saw, true) }
        }
        return (saw, false)
    }
}
