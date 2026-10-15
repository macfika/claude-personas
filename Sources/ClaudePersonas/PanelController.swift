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
final class PanelController {
    static let shared = PanelController()

    private var panel: KeyPanel?
    private var host: NSHostingView<MenuView>?
    private var monitor: Any?
    private var anchor = NSPoint.zero   // top-left corner in screen coordinates

    var isOpen: Bool { panel?.isVisible ?? false }

    func toggle(below button: NSStatusBarButton) { isOpen ? close() : open(below: button) }

    func open(below button: NSStatusBarButton) {
        let p = panel ?? makePanel()
        panel = p
        guard let win = button.window, let screen = win.screen else { return }
        let b = win.convertToScreen(button.convert(button.bounds, to: nil))
        let width: CGFloat = 300
        let x = min(max(b.minX - 12, screen.visibleFrame.minX + 6), screen.visibleFrame.maxX - width - 6)
        anchor = NSPoint(x: x, y: b.minY - 6)
        resize(to: host?.fittingSize ?? NSSize(width: width, height: 300))
        Engine.shared.discoverFolders()
        Engine.shared.refresh()
        p.makeKeyAndOrderFront(nil)
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            MainActor.assumeIsolated { PanelController.shared.close() }
        }
    }

    func close() {
        // Preview runs keep the panel up for screenshots while someone uses the Mac.
        if isPreview && panel?.isVisible == true { return }
        panel?.orderOut(nil)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    func resize(to size: CGSize) {
        guard let panel, size.height > 0 else { return }
        panel.setFrame(NSRect(x: anchor.x, y: anchor.y - size.height, width: size.width, height: size.height), display: true)
    }

    private func makePanel() -> KeyPanel {
        let p = KeyPanel(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
                         backing: .buffered, defer: true)
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let fx = NSVisualEffectView()
        fx.material = .menu
        fx.blendingMode = .behindWindow
        fx.state = .active
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 12
        fx.layer?.cornerCurve = .continuous
        fx.layer?.masksToBounds = true
        fx.layer?.borderWidth = 0.5
        fx.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor

        // Host fills the panel and never sizes it; MenuView reports its height and resize(to:) moves the frame.
        let host = NSHostingView(rootView: MenuView())
        host.sizingOptions = []
        host.frame = fx.bounds
        host.autoresizingMask = [.width, .height]
        fx.addSubview(host)
        self.host = host
        p.contentView = fx
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: p, queue: .main) { _ in
            // A context menu takes key for a moment; only close once the menu is gone.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                MainActor.assumeIsolated {
                    if NSApp.keyWindow == nil || NSApp.keyWindow is AboutWindowType { PanelController.shared.close() }
                }
            }
        }
        return p
    }
}

// MARK: - About window
