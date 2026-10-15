// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Folders {
    static func canonical(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
    }

    // Electron keeps a SingletonLock link in the folder while an instance uses it.
    static func inUse(_ dir: String) -> Bool {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: dir + "/SingletonLock")) != nil
    }

    static func slug(_ name: String) -> String {
        name.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    // Real Claude-* folders (not the symlinks left by renames, not Claude's own Claude-3p).
    static func candidates(in support: String) -> [String] {
        let fm = FileManager.default
        return ((try? fm.contentsOfDirectory(atPath: support)) ?? []).sorted().compactMap { n in
            guard n.hasPrefix("Claude-"), n != "Claude-3p", n.count > 7 else { return nil }
            let path = support + "/" + n
            let type = (try? fm.attributesOfItem(atPath: path))?[.type] as? FileAttributeType
            return type == .typeDirectory ? path : nil
        }
    }

    // Where a profile's folder should live, or nil when it already does or the name is taken.
    static func target(for name: String, current: String, in support: String) -> String? {
        let slug = self.slug(name)
        guard !slug.isEmpty else { return nil }
        let target = support + "/Claude-" + slug
        let fm = FileManager.default
        guard URL(fileURLWithPath: current).lastPathComponent != "Claude-" + slug,
              URL(fileURLWithPath: current).deletingLastPathComponent().standardizedFileURL.path
                == URL(fileURLWithPath: support).standardizedFileURL.path,
              fm.fileExists(atPath: current), !fm.fileExists(atPath: target),
              (try? fm.destinationOfSymbolicLink(atPath: target)) == nil else { return nil }
        return target
    }

    static func move(_ from: String, to: String) -> Bool {
        let fm = FileManager.default
        do {
            try fm.moveItem(atPath: from, toPath: to)
            try fm.createSymbolicLink(atPath: from, withDestinationPath: to)
            return true
        } catch {
            if !fm.fileExists(atPath: from), fm.fileExists(atPath: to) { try? fm.moveItem(atPath: to, toPath: from) }
            return false
        }
    }
}
