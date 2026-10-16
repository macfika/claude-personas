// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

struct NewProfileRow: View {
    @ObservedObject var engine = Engine.shared
    @State private var adding = false

    var body: some View {
        HStack(spacing: 9) {
            Badge(on: false) { Image(systemName: "plus").font(.system(size: 12, weight: .semibold)) }
            if adding {
                NameField(text: "", placeholder: L("Profile name, then Return"),
                          onCommit: { if engine.add(name: $0) { adding = false } },
                          onCancel: { adding = false })
            } else {
                Text(L("New Profile")).font(.system(size: 13)).foregroundStyle(.primary.opacity(0.75))
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .modifier(HoverBackground(radius: 8))
        .onTapGesture { adding = true }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(L("New Profile"))
        .accessibilityAction { adding = true }
    }
}
