import AppKit
import Foundation

// Draws the Islet app icon: a dark rounded tile with a white island pill,
// a notch cutout and a tiny equalizer. Run with `swift icon.swift <out.iconset>`.

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
let fileManager = FileManager.default
try? fileManager.createDirectory(atPath: output, withIntermediateDirectories: true)

func draw(size: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { return nil }

    guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    let s = CGFloat(size)
    let tile = NSRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.225
    let background = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    NSColor(calibratedWhite: 0.035, alpha: 1).setFill()
    background.fill()

    background.addClip()
    let gradient = NSGradient(colors: [
        NSColor(calibratedWhite: 0.15, alpha: 1),
        NSColor(calibratedWhite: 0.02, alpha: 1),
    ])
    gradient?.draw(in: tile, angle: -90)

    // Island pill.
    let pill = NSRect(x: s * 0.18, y: s * 0.50, width: s * 0.64, height: s * 0.21)
    let pillPath = NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.white.withAlphaComponent(0.18)
    shadow.shadowBlurRadius = s * 0.045
    shadow.shadowOffset = .zero
    shadow.set()
    NSColor.white.setFill()
    pillPath.fill()

    NSGraphicsContext.current?.saveGraphicsState()
    let noShadow = NSShadow()
    noShadow.shadowColor = .clear
    noShadow.set()

    // Notch cutout: merges with the tile above the pill.
    let notch = NSRect(
        x: s * 0.40,
        y: s * 0.655,
        width: s * 0.20,
        height: s * 0.085
    )
    let notchPath = NSBezierPath(
        roundedRect: notch,
        xRadius: notch.height * 0.48,
        yRadius: notch.height * 0.48
    )
    NSColor(calibratedWhite: 0.045, alpha: 1).setFill()
    notchPath.fill()

    // Equalizer bars.
    let heights: [CGFloat] = [0.045, 0.075, 0.055]
    let barWidth = s * 0.030
    let baseY = s * 0.545
    for (index, height) in heights.enumerated() {
        let x = s * 0.435 + CGFloat(index) * s * 0.052
        let bar = NSRect(x: x, y: baseY, width: barWidth, height: s * height)
        let path = NSBezierPath(
            roundedRect: bar,
            xRadius: barWidth / 2,
            yRadius: barWidth / 2
        )
        NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
        path.fill()
    }

    NSGraphicsContext.current?.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in variants {
    guard let data = draw(size: size) else { continue }
    try? data.write(to: URL(fileURLWithPath: output).appendingPathComponent(name))
    print("wrote \(name)")
}
