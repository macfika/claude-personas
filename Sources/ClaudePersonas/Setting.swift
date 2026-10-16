// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Setting: String, CaseIterable, Identifiable {
    case launchAtLogin, autoUpdate, routeSignIn, reopenAfterUpdate, shortcut, profileShortcuts, showActive, showCount, coloredIcon, dockApps, quitWithApp

    static let onByDefault: Set<Setting> = [.autoUpdate, .routeSignIn, .reopenAfterUpdate, .showActive, .showCount]

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .launchAtLogin: L("Launch at Login")
        case .autoUpdate: L("Update Claude Personas Automatically")
        case .routeSignIn: L("Sign In in Each Account's Window")
        case .reopenAfterUpdate: L("Reopen After Claude Updates")
        case .shortcut: L("Keyboard Shortcut")
        case .profileShortcuts: L("Profile Shortcuts")
        case .showActive: L("Show Active Account in Menu Bar")
        case .showCount: L("Show Count in Menu Bar")
        case .coloredIcon: L("Colored Menu Bar Icon")
        case .dockApps: L("App for Each Profile")
        case .quitWithApp: L("Quit Profiles with Claude Personas")
        }
    }

    var symbol: String {
        switch self {
        case .launchAtLogin: "power"
        case .autoUpdate: "arrow.down.circle"
        case .routeSignIn: "person.badge.key"
        case .reopenAfterUpdate: "arrow.clockwise"
        case .shortcut: "command"
        case .profileShortcuts: "keyboard"
        case .showActive: "menubar.rectangle"
        case .showCount: "number"
        case .coloredIcon: "paintpalette"
        case .dockApps: "dock.rectangle"
        case .quitWithApp: "xmark.circle"
        }
    }

    @MainActor var hint: String? {
        switch self {
        case .shortcut: "⌃⌥⌘M"
        case .profileShortcuts: L("⌃⌥1 to 9")
        default: nil
        }
    }
}

// MARK: - Engine
