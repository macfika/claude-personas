// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

struct ProfileRow: View {
    let profile: Profile
    @ObservedObject var engine = Engine.shared
    @Binding var editing: UUID?
    @State private var hover = false

    var body: some View {
        let on = engine.isRunning(profile)
        HStack(spacing: 9) {
            Badge(on: on, tint: profile.tint, offTint: profile.tint) {
                if engine.isStarting(profile) {
                    ProgressView().controlSize(.mini)
                } else {
                    Text(profile.initial).font(.system(size: 12, weight: .bold))
                }
            }
            if editing == profile.id {
                NameField(text: profile.name, placeholder: "Profile name",
                          onCommit: { engine.rename(profile, to: $0); editing = nil },
                          onCancel: { editing = nil })
            } else {
                Text(profile.name).font(.system(size: 13)).foregroundStyle(.primary.opacity(on ? 1 : 0.75))
                if profile.isDefault {
                    Text("Default").font(.system(size: 10)).foregroundStyle(.tertiary)
                }
                if let hint = engine.shortcutHint(for: profile) {
                    Text(hint).font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 4)
            if on && hover {
                Button("Quit \(profile.name)", systemImage: "xmark.circle.fill") { engine.quit(profile) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .contentShape(Circle())

                    .help("Quit \(profile.name)")
            } else if on {
                Text(engine.frontID == profile.id ? "Active" : "Running").font(.system(size: 10)).foregroundStyle(profile.tint)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .modifier(HoverBackground(radius: 8))
        .onHover { hover = $0 }
        .onTapGesture {
            guard editing != profile.id else { return }
            engine.open(profile)
            if !on { PanelController.shared.close() }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(profile.name), \(on ? "running" : "closed")")
        .accessibilityAction { engine.open(profile) }
        .contextMenu {
            Button(on ? "Show \(profile.name)" : "Open \(profile.name)") { engine.open(profile) }
            if on { Button("Quit \(profile.name)") { engine.quit(profile) } }
            Button("Sign In to \(profile.name)…") { Dialogs.signIn(profile) }
            Button("Open Claude Code in Terminal") { engine.openClaudeCode(profile) }
            Toggle("Open When Claude Personas Starts", isOn: Binding(get: { profile.openAtLaunch == true },
                                                                 set: { engine.setOpenAtLaunch(profile, $0) }))
            Divider()
            Button("Rename…") { editing = profile.id }
            Menu("Color") {
                ForEach(Palette.colors.indices, id: \.self) { i in
                    Toggle(Palette.colors[i].name, isOn: Binding(get: { (profile.color ?? 0) == i },
                                                                 set: { _ in engine.setColor(profile, i) }))
                }
            }
            Button("Move Up") { engine.move(profile, by: -1) }
            Button("Move Down") { engine.move(profile, by: 1) }
            Divider()
            Button("Show Data Folder in Finder") { NSWorkspace.shared.activateFileViewerSelecting([profile.folderURL]) }
            if let app = engine.launcherURL(profile) {
                if Dock.contains(app) {
                    Button("Remove \(profile.dockAppName) from Dock") { engine.removeFromDock(profile) }
                } else {
                    Button("Add \(profile.dockAppName) to Dock") { engine.addToDock(profile) }
                }
                Button("Rename App…") { Dialogs.renameApp(profile) }
                Button("Show App in Finder") { NSWorkspace.shared.activateFileViewerSelecting([app]) }
            } else {
                Button("Add \(profile.dockAppName) to Dock") { engine.addToDock(profile) }
            }
            Button("Copy Shell Alias") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(profile.shellAlias, forType: .string)
            }
            Button("Copy Claude Code Alias") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(profile.codeAlias, forType: .string)
            }
            Divider()
            Menu("Copy MCP Servers From") {
                let sources = engine.profiles.filter { $0.id != profile.id }.map { ($0, MCP.servers($0).count) }.filter { $0.1 > 0 }
                if sources.isEmpty {
                    Text("No other profile has MCP servers")
                }
                ForEach(sources, id: \.0.id) { src, n in
                    Button("\(src.name) (\(n))") { Dialogs.copyMCP(from: src, to: profile) }
                }
            }
            Button("Duplicate as New Profile…") { Dialogs.duplicate(profile) }
            if !profile.isDefault {
                Divider()
                Button("Remove from List") { engine.remove(profile) }
            }
        }
    }
}

// Confirmations for actions that quit a window or write into a profile's folder.
