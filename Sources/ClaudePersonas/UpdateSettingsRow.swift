// Copyright 2026 macfika. SPDX-License-Identifier: Apache-2.0
import SwiftUI

struct UpdateSettingsRow: View {
    @ObservedObject private var updates = UpdateController.shared

    var body: some View {
        switch updates.channel {
        case .manual:
            Button(action: updates.toggleAutomaticChecks) {
                SettingsRowLabel(
                    title: L("Update Claude Personas Automatically"),
                    symbol: "arrow.down.circle",
                    on: updates.automaticChecksEnabled
                )
            }
            .buttonStyle(.plain)
            .accessibilityValue(updates.automaticChecksEnabled ? L("On") : L("Off"))
            Button(action: updates.checkForUpdates) {
                SettingsRowLabel(title: L("Check for Updates…"), symbol: "arrow.clockwise", on: true)
            }
            .buttonStyle(.plain)
            .disabled(!updates.canCheckForUpdates)
        case .homebrew, .uncertainHomebrew:
            Button(action: updates.showHomebrewInstructions) {
                SettingsRowLabel(
                    title: L("Update with Homebrew"),
                    symbol: "terminal",
                    on: true,
                    detail: updates.channel == .homebrew
                        ? L("Updates are managed by Homebrew.")
                        : L("Updates are disabled because this Homebrew installation record could not be verified.")
                )
            }
            .buttonStyle(.plain)
        case .development:
            SettingsRowLabel(
                title: L("Check for Updates…"),
                symbol: "arrow.down.circle",
                on: false,
                detail: L("Automatic updates are unavailable in development builds.")
            )
            .accessibilityElement(children: .combine)
        }
    }
}
