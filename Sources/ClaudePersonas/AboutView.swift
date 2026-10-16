// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

struct AboutView: View {
    var body: some View {
        HStack(spacing: 34) {
            Image(nsImage: AppIcon.image(512)).resizable().frame(width: 170, height: 170)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Claude Personas")).font(.system(size: 32, weight: .semibold))
                Text(L("Version %@", appVersion)).font(.system(size: 13))
                Text(L("A native SwiftUI menu bar manager for independent Claude Desktop profiles. Based on MultiClaude by Quentin Caron / Soma Labs, licensed under Apache 2.0. Maintained at macfika/claude-personas."))
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                HStack(spacing: 18) {
                    Button(L("Issues")) { NSWorkspace.shared.open(supportURL) }
                    Button(L("GitHub")) { NSWorkspace.shared.open(websiteURL) }
                }
                .buttonStyle(PillButtonStyle())
                .padding(.top, 18)
            }
            .frame(width: 330, alignment: .leading)
        }
        .padding(.horizontal, 40)
        .padding(.top, 30)
        .padding(.bottom, 44)
        .frame(width: 620, height: 360)
        .overlay(alignment: .bottom) {
            Text(L("Original work © 2026 Soma Labs. Modifications © 2026 macfika. Apache 2.0."))
                .font(.system(size: 11)).foregroundStyle(.tertiary).padding(.bottom, 22)
        }
        .environment(\.locale, Localization.shared.locale)
    }
}
