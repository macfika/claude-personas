// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

struct MenuContent: View {
    @ObservedObject var engine = Engine.shared
    @AppStorage("profilesOpen") private var profilesOpen = true
    @AppStorage("settingsOpen") private var settingsOpen = false
    @State private var editing: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The switch reads "any profile running": on opens every profile, off quits them all.
            HStack {
                Text(L("Claude Personas")).font(.system(size: 13, weight: .bold))
                Spacer()
                Toggle(L("Open all profiles"), isOn: Binding(get: { engine.runningCount > 0 },
                                         set: { $0 ? engine.openAll() : engine.quitAll() }))
                    .toggleStyle(.switch).controlSize(.regular).labelsHidden().tint(.claude)
                    .help(L("On opens every profile, off quits them all"))
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            if let notice = engine.notice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: engine.signIn != nil ? "person.badge.key" : notice.hasPrefix(L("Claude Personas")) ? "arrow.down.circle" : "arrow.clockwise")
                        .foregroundStyle(Color.claude)
                    Text(notice).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if engine.signIn != nil {
                        Button(L("Done")) { engine.finishSignIn(cancelled: false) }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Capsule().fill(Color.claude))

                            .help(L("Reopen the other accounts now"))
                    } else {
                        Button(L("Dismiss notice"), systemImage: "xmark") { engine.dismissNotice() }
                            .labelStyle(.iconOnly).buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12))
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            Divider().padding(.horizontal, 14)
            SectionHeader(title: L("Profiles (%@)", String(engine.profiles.count)),
                          trailing: engine.runningCount > 0 ? L("%@ running", String(engine.runningCount)) : L("None running"),
                          open: $profilesOpen)
            if profilesOpen {
                VStack(spacing: 0) {
                    ForEach(engine.profiles) { ProfileRow(profile: $0, editing: $editing) }
                    NewProfileRow()
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
            }

            Divider().padding(.horizontal, 14)
            SectionHeader(title: L("Settings"), open: $settingsOpen)
            if settingsOpen {
                VStack(spacing: 0) {
                    LanguagePickerRow()
                    ForEach(Setting.allCases) { SettingRow(setting: $0) }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 5)
            }

            Divider().padding(.horizontal, 14)
            VStack(spacing: 0) {
                PlainRow(title: L("About")) { PanelController.shared.close(); AboutWindow.show() }
                PlainRow(title: L("Quit")) { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
        }
        .frame(width: 300)
        .fixedSize(horizontal: false, vertical: true)

    }
}

// MARK: - Panel window
