import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Solo-island brand art.
//
//   swift Resources/icon.swift icon build/AppIcon.iconset
//   swift Resources/icon.swift logo docs
//
// The app icon is the island alone on a transparent canvas (no tile). The logo
// mode writes a static PNG and an animated GIF with the equalizer breathing.

func drawIsland(
    canvas: NSSize,
    islandWidth: CGFloat,
    islandHeight: CGFloat,
    phase: Double
) -> NSBitmapImageRep? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas.width),
        pixelsHigh: Int(canvas.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: canvas).fill()

    let pill = NSRect(
        x: (canvas.width - islandWidth) / 2,
        y: (canvas.height - islandHeight) / 2,
        width: islandWidth,
        height: islandHeight
    )
    let radius = islandHeight / 2
    let pillPath = NSBezierPath(roundedRect: pill, xRadius: radius, yRadius: radius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowBlurRadius = islandHeight * 0.16
    shadow.shadowOffset = NSSize(width: 0, height: -islandHeight * 0.05)
    shadow.set()

    NSColor.white.setFill()
    pillPath.fill()

    let noShadow = NSShadow()
    noShadow.shadowColor = .clear
    noShadow.set()

    // Notch: a black bite clipped to the pill so the top edge stays flat.
    NSGraphicsContext.current?.saveGraphicsState()
    pillPath.addClip()
    let notchWidth = islandWidth * 0.30
    let notchHeight = islandHeight * 0.34
    let notch = NSRect(
        x: pill.midX - notchWidth / 2,
        y: pill.maxY - notchHeight + islandHeight * 0.12,
        width: notchWidth,
        height: notchHeight
    )
    NSColor.black.setFill()
    NSBezierPath(
        roundedRect: notch,
        xRadius: notchHeight * 0.40,
        yRadius: notchHeight * 0.40
    ).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    // Equalizer bars.
    let heights: [CGFloat] = [
        0.18 + 0.10 * CGFloat(sin(phase)),
        0.30 + 0.14 * CGFloat(sin(phase + 2.1)),
        0.22 + 0.12 * CGFloat(sin(phase + 4.2)),
    ]
    let barWidth = islandWidth * 0.038
    let spacing = islandWidth * 0.055
    let baseY = pill.minY + islandHeight * 0.18

    for (index, height) in heights.enumerated() {
        let x = pill.midX + (CGFloat(index) - 1) * spacing - barWidth / 2
        let bar = NSRect(
            x: x,
            y: baseY,
            width: barWidth,
            height: islandHeight * height
        )
        NSColor.black.setFill()
        NSBezierPath(
            roundedRect: bar,
            xRadius: barWidth / 2,
            yRadius: barWidth / 2
        ).fill()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: url)
}

func makeIconSet(_ output: String) {
    let manager = FileManager.default
    try? manager.createDirectory(atPath: output, withIntermediateDirectories: true)

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
        let s = CGFloat(size)
        guard let rep = drawIsland(
            canvas: NSSize(width: s, height: s),
            islandWidth: s * 0.80,
            islandHeight: s * 0.35,
            phase: 0.6
        ) else { continue }
        writePNG(rep, to: URL(fileURLWithPath: output).appendingPathComponent(name))
        print("wrote \(name)")
    }
}

func makeLogo(_ output: String) {
    let manager = FileManager.default
    try? manager.createDirectory(atPath: output, withIntermediateDirectories: true)
    let directory = URL(fileURLWithPath: output, isDirectory: true)

    let canvas = NSSize(width: 600, height: 260)
    let islandWidth: CGFloat = 520
    let islandHeight: CGFloat = 180

    if let still = drawIsland(
        canvas: canvas,
        islandWidth: islandWidth,
        islandHeight: islandHeight,
        phase: 0.6
    ) {
        writePNG(still, to: directory.appendingPathComponent("logo.png"))
        print("wrote logo.png")
    }

    let frameCount = 24
    let gifURL = directory.appendingPathComponent("logo.gif")
    guard let destination = CGImageDestinationCreateWithURL(
        gifURL as CFURL,
        UTType.gif.identifier as CFString,
        frameCount,
        nil
    ) else { return }

    let gifProperties: [CFString: Any] = [
        kCGImagePropertyGIFDictionary: [
            kCGImagePropertyGIFLoopCount: 0
        ]
    ]
    CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

    for frame in 0..<frameCount {
        let phase = Double(frame) / Double(frameCount) * .pi * 2
        guard let rep = drawIsland(
            canvas: canvas,
            islandWidth: islandWidth,
            islandHeight: islandHeight,
            phase: phase
        ), let image = rep.cgImage else { continue }
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: 0.08
            ]
        ]
        CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
    }

    if CGImageDestinationFinalize(destination) {
        print("wrote logo.gif")
    }
}

let arguments = CommandLine.arguments
let mode = arguments.count > 1 ? arguments[1] : "icon"
let output = arguments.count > 2 ? arguments[2] : (mode == "logo" ? "docs" : "AppIcon.iconset")

switch mode {
case "logo":
    makeLogo(output)
default:
    makeIconSet(output)
}
