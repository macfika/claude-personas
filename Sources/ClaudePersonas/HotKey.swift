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
enum HotKey {
    struct Binding {
        let key: Int
        let mods: Int
        let action: () -> Void
    }

    static let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                         kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
    static var refs: [EventHotKeyRef] = []
    static var actions: [UInt32: () -> Void] = [:]
    static var installed = false

    static func register(_ list: [Binding]) {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        actions = [:]
        if !installed && !list.isEmpty {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hk = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
                MainActor.assumeIsolated { HotKey.actions[hk.id]?() }
                return noErr
            }, 1, &spec, nil, nil)
            installed = true
        }
        for (i, b) in list.enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: OSType(0x4D43_4C44), id: UInt32(i + 1))
            if RegisterEventHotKey(UInt32(b.key), UInt32(b.mods), id, GetApplicationEventTarget(), 0, &ref) == noErr, let ref {
                refs.append(ref)
                actions[UInt32(i + 1)] = b.action
            }
        }
    }
}

// MARK: - App icon (drawn, so the bundle needs no image files)
