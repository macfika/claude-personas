// Copyright 2026 Soma Labs. Modifications Copyright 2026 macfika.
// SPDX-License-Identifier: Apache-2.0
// Derived from https://github.com/QuentinCar0n/multiclaude (main.swift).
// Modified for Claude Personas: separate sources, identity, release trust and safety fixes.
import AppKit
import SwiftUI
import ServiceManagement
import Carbon.HIToolbox
import CryptoKit

enum AppIcon {
    // ClaudePersonas's own icon: the Claude asterisk on an orange tile.
    static func image(_ side: CGFloat) -> NSImage { tile(side, color: .claude, letter: nil) }

    // A tile in `color` with the white asterisk, or with `letter` and a small asterisk in the corner
    // (the icon of a profile's app).
    static func tile(_ side: CGFloat, color: NSColor, letter: String?) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { r in
            let inset = r.width * 0.1
            let tile = r.insetBy(dx: inset, dy: inset)
            let path = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = .black.withAlphaComponent(0.3)
            shadow.shadowBlurRadius = r.width * 0.025
            shadow.shadowOffset = NSSize(width: 0, height: -r.width * 0.01)
            shadow.set()
            color.setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()
            let base = color.usingColorSpace(.sRGB) ?? color
            NSGradient(colors: [base.blended(withFraction: 0.18, of: .white) ?? base,
                                base.blended(withFraction: 0.12, of: .black) ?? base])?.draw(in: path, angle: -90)
            func asterisk(size: CGFloat, center: NSPoint) {
                let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: .semibold)
                    .applying(.init(paletteColors: [.white]))
                guard let sym = NSImage(systemSymbolName: "asterisk", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
                let s = sym.size
                sym.draw(in: NSRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height))
            }
            guard let letter, !letter.isEmpty else {
                asterisk(size: tile.width * 0.5, center: NSPoint(x: tile.midX, y: tile.midY))
                return true
            }
            let font = NSFont.systemFont(ofSize: tile.width * 0.56, weight: .bold)
            let rounded = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: font.pointSize) } ?? font
            let text = NSAttributedString(string: letter, attributes: [.font: rounded, .foregroundColor: NSColor.white])
            let ts = text.size()
            text.draw(at: NSPoint(x: tile.midX - ts.width / 2, y: tile.midY - ts.height / 2 - tile.height * 0.03))
            asterisk(size: tile.width * 0.15, center: NSPoint(x: tile.maxX - tile.width * 0.2, y: tile.maxY - tile.height * 0.2))
            return true
        }
    }

    // A profile's icon: Claude's own icon, read from Claude.app, with its orange turned to the profile's
    // color. The dark tile stays as it is. Falls back to a letter tile when Claude.app can't be read.
    static func profile(_ side: CGFloat, color: NSColor, letter: String) -> NSImage {
        claudeTinted(side, color: color) ?? tile(side, color: color, letter: letter)
    }

    static func claudeTinted(_ side: CGFloat, color: NSColor) -> NSImage? {
        let src = NSWorkspace.shared.icon(forFile: realClaudeApp().path)
        var rect = NSRect(x: 0, y: 0, width: side, height: side)
        guard let cg = src.cgImage(forProposedRect: &rect, context: nil, hints: nil) else { return nil }
        let orange = NSColor.claude.usingColorSpace(.sRGB)!, target = color.usingColorSpace(.sRGB) ?? color
        var image = CIImage(cgImage: cg)
        // Rotate the hue from Claude orange to the target; a grey target drains the color instead.
        let hue = CIFilter(name: "CIHueAdjust")!
        hue.setValue(image, forKey: kCIInputImageKey)
        hue.setValue((target.hueComponent - orange.hueComponent) * 2 * .pi, forKey: kCIInputAngleKey)
        image = hue.outputImage ?? image
        let controls = CIFilter(name: "CIColorControls")!
        controls.setValue(image, forKey: kCIInputImageKey)
        controls.setValue(min(1.2, target.saturationComponent / max(orange.saturationComponent, 0.01)), forKey: kCIInputSaturationKey)
        image = controls.outputImage ?? image
        guard let out = CIContext().createCGImage(image, from: image.extent) else { return nil }
        return NSImage(cgImage: out, size: NSSize(width: side, height: side))
    }

    static func png(_ image: NSImage, pixels px: Int) -> Data? {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    // An .icns file with every size, written with ImageIO so no command-line tool is needed.
    static func icns(_ draw: (CGFloat) -> NSImage) -> Data? {
        let sizes = [16, 32, 64, 128, 256, 512, 1024]
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, "com.apple.icns" as CFString, sizes.count, nil) else { return nil }
        for px in sizes {
            guard let data = png(draw(CGFloat(px)), pixels: px),
                  let src = CGImageSourceCreateWithData(data as CFData, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
            CGImageDestinationAddImage(dest, img, nil)
        }
        return CGImageDestinationFinalize(dest) ? out as Data : nil
    }

    // build.sh calls `ClaudePersonas --export-iconset <dir>` to make the .icns.
    static func exportIconset(to dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for base in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let px = base * scale
                let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
                try? png(image(CGFloat(px)), pixels: px)?.write(to: URL(fileURLWithPath: dir + "/" + name))
            }
        }
    }
}

// MARK: - Profile apps

// The Claude that runs for a profile while profile apps are on: an APFS clone of Claude.app (clonefile,
// instant and free on disk) in a .noindex folder, so Spotlight lists only the launcher. The clone wears the
// profile's icon as a Finder custom icon (outside the signed Contents folder), which macOS shows for the
// running window in the Dock, ⌘-Tab and Mission Control. Nothing inside the bundle changes, so the
// signature stays valid: Gatekeeper accepts it, the Keychain still hands it "Claude Safe Storage", and
// Claude still names its own folders "Claude". Tested 2026-10-10: adding an InfoPlist.strings to rename the
// running app breaks the resource seal and Gatekeeper then calls the copy damaged at every launch, so the
// running window keeps the name Claude. A clone is refreshed from Claude.app when Claude updates, only
// while that profile is closed; one that Claude's updater moved ahead is restyled in place.
