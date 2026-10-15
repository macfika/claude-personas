// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    func applicationWillFinishLaunching(_ n: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleLink(_:reply:)),
                                                     forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }

    @objc func handleLink(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let link = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        if link.lowercased().hasPrefix("claude-personas:") { Engine.shared.handleOwnLink(link); return }
        guard URLComponents(string: link)?.scheme?.lowercased() == "claude" else { return }
        Engine.shared.relay(link)
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        // A crash during a sign-in would leave ClaudePersonas as the claude:// handler; hand the links back.
        LinkRelay.giveBack()
        switch ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_APPEARANCE"] {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        if let b = item.button {
            b.target = self
            b.action = #selector(clicked)
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
            b.imagePosition = .imageLeading
        }
        let engine = Engine.shared
        engine.onChange = { [weak self] in self?.refreshIcon() }
        engine.onPanelHotKey = { [weak self] in
            if let b = self?.item.button { PanelController.shared.toggle(below: b) }
        }
        engine.boot()
        refreshIcon()
        // Preview hook for screenshots: CLAUDE_PERSONAS_PREVIEW=panel|settings|about
        switch ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_PREVIEW"] {
        case "panel", "settings":
            UserDefaults.standard.set(ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_PREVIEW"] == "settings", forKey: "settingsOpen")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if let b = self?.item.button { PanelController.shared.open(below: b) }
            }
        case "signin":   // CLAUDE_PERSONAS_SIGNIN_TARGET=<profile name> starts Sign In for that profile, for live tests
            let name = ProcessInfo.processInfo.environment["CLAUDE_PERSONAS_SIGNIN_TARGET"] ?? ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if let p = Engine.shared.profiles.first(where: { $0.name == name }) { Engine.shared.beginSignIn(p) }
            }
        case "about": AboutWindow.show()
        default: break
        }
    }

    func applicationWillTerminate(_ n: Notification) {
        LinkRelay.giveBack()
        if Engine.shared.isOn(.quitWithApp) && !Updater.relaunching { Engine.shared.quitAll() }
    }

    @objc private func clicked() {
        guard let button = item.button else { return }
        PanelController.shared.toggle(below: button)
    }

    private func refreshIcon() {
        guard let b = item.button else { return }
        let engine = Engine.shared
        let count = engine.runningCount
        let img = NSImage(systemSymbolName: "asterisk", accessibilityDescription: "Claude Personas")
        // While a Claude window is in front, the menu bar names its account in the profile's color.
        let front = engine.isOn(.showActive) ? engine.profiles.first { $0.id == engine.frontID } : nil
        if let front {
            b.image = img?.withSymbolConfiguration(.init(paletteColors: [front.nsTint]))
            b.image?.isTemplate = false
        } else if count > 0 && engine.isOn(.coloredIcon) {
            b.image = img?.withSymbolConfiguration(.init(paletteColors: [.claude]))
            b.image?.isTemplate = false
        } else {
            b.image = img
            b.image?.isTemplate = true
        }
        if let front {
            b.title = " " + front.name
        } else {
            b.title = count > 0 && engine.isOn(.showCount) ? " \(count)" : ""
        }
        b.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
    }
}
