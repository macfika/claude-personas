// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Duplicate {
    // `cp -c` clones on APFS. The destination must not exist yet.
    static func clone(from src: String, to dst: String) -> Bool {
        let fm = FileManager.default
        // An imported/renamed profile may use a compatibility symlink. Copy the real directory,
        // never the symlink: otherwise both profiles would share data and lock removal hits the source.
        let source = Folders.canonical(src), destination = Folders.canonical(dst)
        guard (try? fm.attributesOfItem(atPath: source)[.type]) as? FileAttributeType == .typeDirectory,
              !fm.fileExists(atPath: dst), (try? fm.destinationOfSymbolicLink(atPath: dst)) == nil,
              source != destination, !destination.hasPrefix(source + "/") else { return false }
        do { try Updater.run("/bin/cp", ["-cR", source, dst]) } catch {
            try? fm.removeItem(atPath: dst)
            return false
        }
        // Electron's single-instance lock files belong to the source process.
        for lock in ["SingletonLock", "SingletonSocket", "SingletonCookie"] {
            try? fm.removeItem(atPath: dst + "/" + lock)
        }
        return true
    }
}
