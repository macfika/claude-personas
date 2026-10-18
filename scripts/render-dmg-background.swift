#!/usr/bin/env swift
import AppKit

// Finder positions icons in points, measured from the window's top-left corner.
// Keep the spaces around (180, 220) and (540, 220) free for the real icons.
let width = 720.0
let height = 480.0
let scale = 2.0

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render-dmg-background.swift OUTPUT.png\n", stderr)
    exit(1)
}

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width * scale),
    pixelsHigh: Int(height * scale),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fputs("Unable to create the DMG background canvas.\n", stderr)
    exit(1)
}
bitmap.size = NSSize(width: width, height: height)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.cgContext.scaleBy(x: scale, y: scale)

func topRect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> NSRect {
    NSRect(x: x, y: height - y - h, width: w, height: h)
}

func text(_ value: String, top: Double, size: Double, weight: NSFont.Weight = .regular,
          color: NSColor = NSColor(calibratedWhite: 0.29, alpha: 1)) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byClipping
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    (value as NSString).draw(in: topRect(24, top, width - 48, size + 9), withAttributes: attributes)
}

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSGradient(starting: NSColor(calibratedWhite: 0.99, alpha: 1),
           ending: NSColor(calibratedWhite: 0.94, alpha: 1))!.draw(in: canvas, angle: -90)

text("Claude Personas", top: 35, size: 31, weight: .semibold,
     color: NSColor(calibratedWhite: 0.16, alpha: 1))
text("安装 · Install", top: 79, size: 14, weight: .medium,
     color: NSColor(calibratedWhite: 0.46, alpha: 1))

let arrow = NSBezierPath()
arrow.lineWidth = 3.5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: NSPoint(x: 324, y: height - 220))
arrow.line(to: NSPoint(x: 396, y: height - 220))
arrow.move(to: NSPoint(x: 383, y: height - 207))
arrow.line(to: NSPoint(x: 396, y: height - 220))
arrow.line(to: NSPoint(x: 383, y: height - 233))
NSColor(calibratedWhite: 0.60, alpha: 1).setStroke()
arrow.stroke()

let instructions = [
    "将 Claude Personas 拖到右侧 Applications 文件夹",
    "將 Claude Personas 拖到右側 Applications 資料夾",
    "Claude Personas を右の Applications フォルダにドラッグ",
    "Claude Personas를 오른쪽 Applications 폴더로 드래그하세요",
    "Drag Claude Personas to the Applications folder on the right."
]
for (index, instruction) in instructions.enumerated() {
    text(instruction, top: 313 + Double(index) * 22, size: 14)
}

text("然后从应用程序打开 / Then open from Applications", top: 444, size: 12,
     color: NSColor(calibratedWhite: 0.48, alpha: 1))

NSGraphicsContext.restoreGraphicsState()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode the DMG background.\n", stderr)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
} catch {
    fputs("Unable to write the DMG background: \(error.localizedDescription)\n", stderr)
    exit(1)
}
