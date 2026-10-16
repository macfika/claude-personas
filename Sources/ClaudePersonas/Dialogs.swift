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
enum Dialogs {
    static func alert(_ title: String, _ text: String, buttons: [String], field: String? = nil) -> (Int, String) {
        PanelController.shared.close()
        NSApp.activate()
        let a = NSAlert()
        a.messageText = title
        a.informativeText = text
        buttons.forEach { a.addButton(withTitle: $0) }
        var input: NSTextField?
        if let field {
            let f = NSTextField(string: field)
            f.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
            a.accessoryView = f
            a.window.initialFirstResponder = f
            input = f
        }
        let r = a.runModal().rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        return (r, input?.stringValue ?? "")
    }

    static func copyMCP(from src: Profile, to dst: Profile) {
        let e = Engine.shared
        let n = MCP.servers(src).count
        let running = e.isRunning(dst)
        let buttons = running ? [L("Copy and Reopen %@", dst.name), L("Copy"), L("Cancel")] : [L("Copy"), L("Cancel")]
        let (choice, _) = alert(L("Copy MCP servers (%@) from %@ to %@?", String(n), src.name, dst.name),
                                L("Servers with the same name in %@ are replaced. %@'s current config is backed up next to it first. Keys and tokens in the server settings are copied too.", dst.name, dst.name),
                                buttons: buttons)
        if choice == buttons.count - 1 { return }
        e.copyMCPServers(from: src, to: dst, restart: running && choice == 0)
    }

    static func renameApp(_ p: Profile) {
        let (choice, name) = alert(L("Rename %@", p.dockAppName),
                                   L("This name shows in the Dock, Spotlight and Launchpad. Leave it empty to go back to \"%@\". The Claude window itself keeps the name Claude.", Profile(name: p.name, dir: p.dir).dockAppName),
                                   buttons: [L("Rename"), L("Cancel")], field: p.dockAppName)
        guard choice == 0 else { return }
        Engine.shared.renameApp(p, to: name)
    }

    static func signIn(_ p: Profile) {
        Engine.shared.beginSignIn(p)
    }

    static func duplicate(_ src: Profile) {
        let e = Engine.shared
        let running = e.isRunning(src)
        let text = L("The new profile gets a copy of %@'s data: its sign-in, chats and settings. The copy is instant and uses no extra disk space until the two change.", src.name)
            + (running ? " " + L("%@ has to quit while it's copied, then it reopens.", src.name) : "")
        let (choice, name) = alert(L("Duplicate %@", src.name), text,
                                   buttons: [running ? L("Quit %@ and Duplicate", src.name) : L("Duplicate"), L("Cancel")],
                                   field: L("%@ copy", src.name))
        guard choice == 0 else { return }
        guard e.newProfile(named: name) != nil else {
            _ = alert(L("Pick another name"), L("\"%@\" is empty or already used by a profile or folder.", name), buttons: [L("OK")])
            return
        }
        e.duplicate(src, as: name)
    }
}
