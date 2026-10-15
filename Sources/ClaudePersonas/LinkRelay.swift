// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum LinkRelay {
    static var claudeApp: URL { realClaudeApp() }

    static func handler() -> URL? {
        NSWorkspace.shared.urlForApplication(toOpen: URL(string: "claude://claude.ai")!)
    }

    static func isOurs() -> Bool {
        handler()?.standardizedFileURL.path == Bundle.main.bundleURL.standardizedFileURL.path
    }

    static func take(_ done: @escaping @Sendable (Bool) -> Void) {
        guard !isDemo, !isCLI else { done(false); return }
        Log.write("taking claude:// links")
        NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "claude") { err in
            done(err == nil && isOurs())
        }
    }

    static func giveBack() {
        guard !isDemo, !isCLI, isOurs() else { return }
        Log.write("giving claude:// links back to Claude")
        NSWorkspace.shared.setDefaultApplication(at: claudeApp, toOpenURLsWithScheme: "claude") { _ in }
    }

    // macOS 14+ only lets the active app hand focus over explicitly; ClaudePersonas is active while it takes a link.
    @MainActor static func bringForward(_ app: NSRunningApplication) {
        app.unhide()
        NSApp.yieldActivation(to: app)
        app.activate(from: NSRunningApplication.current, options: [])
    }

    // The same "open URL" Apple Event macOS would send, aimed at one process instead of the first one found.
    static func send(_ link: String, to pid: pid_t) -> Bool {
        let ev = NSAppleEventDescriptor(eventClass: AEEventClass(kInternetEventClass), eventID: AEEventID(kAEGetURL),
                                        targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
                                        returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
        ev.setParam(NSAppleEventDescriptor(string: link), forKeyword: keyDirectObject)
        return (try? ev.sendEvent(options: [.noReply], timeout: 5)) != nil
    }
}
