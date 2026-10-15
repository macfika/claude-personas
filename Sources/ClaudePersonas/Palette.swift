// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum Palette {
    static let colors: [(name: String, color: NSColor)] = [
        ("Orange", .claude),
        ("Blue", NSColor(srgbRed: 0.29, green: 0.55, blue: 0.96, alpha: 1)),
        ("Green", NSColor(srgbRed: 0.27, green: 0.69, blue: 0.44, alpha: 1)),
        ("Purple", NSColor(srgbRed: 0.62, green: 0.45, blue: 0.91, alpha: 1)),
        ("Pink", NSColor(srgbRed: 0.91, green: 0.41, blue: 0.62, alpha: 1)),
        ("Teal", NSColor(srgbRed: 0.18, green: 0.66, blue: 0.71, alpha: 1)),
        ("Yellow", NSColor(srgbRed: 0.88, green: 0.67, blue: 0.18, alpha: 1)),
        ("Graphite", NSColor(srgbRed: 0.52, green: 0.52, blue: 0.55, alpha: 1)),
    ]
}
