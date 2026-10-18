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
            SettingsRowLabel(title: setting.title, symbol: setting.symbol, on: on, hint: setting.hint)
        }
        .buttonStyle(.plain)
        .accessibilityValue(on ? L("On") : L("Off"))
    }
}
