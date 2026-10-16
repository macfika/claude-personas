// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

struct SettingRow: View {
    let setting: Setting
    @ObservedObject var engine = Engine.shared

    var body: some View {
        let on = engine.isOn(setting)
        Button { engine.toggle(setting) } label: {
        HStack(spacing: 9) {
            Badge(on: on) { Image(systemName: setting.symbol).font(.system(size: 12, weight: .medium)) }
            Text(setting.title).font(.system(size: 13)).foregroundStyle(.primary.opacity(on ? 1 : 0.75))
            Spacer(minLength: 4)
            if let hint = setting.hint {
                Text(hint).font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .modifier(HoverBackground(radius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityValue(on ? L("On") : L("Off"))
    }
}
