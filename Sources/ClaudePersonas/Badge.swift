// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

struct Badge<Label: View>: View {
    let on: Bool
    var tint: Color = .claude
    var offTint: Color = .primary
    @ViewBuilder let label: Label
    var body: some View {
        label
            .foregroundStyle(on ? Color.white : offTint)
            .frame(width: 24, height: 24)
            .background(Circle().fill(on ? tint : Color.primary.opacity(0.12)))
    }
}
