// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

struct PlainRow: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Text(title).font(.system(size: 13)); Spacer() }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .modifier(HoverBackground(radius: 6))
        }
        .buttonStyle(.plain)
    }
}
