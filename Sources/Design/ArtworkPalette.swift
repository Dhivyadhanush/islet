import AppKit
import SwiftUI

/// Pulls a usable accent colour out of album artwork.
///
/// The player tints its progress bar, play button and artwork glow with this
/// colour so each track brings its own palette. Sampling is done on a tiny
/// bitmap and cached per artwork image, so it is cheap enough to call from
/// `body`.
enum ArtworkPalette {
    private static var cache: [ObjectIdentifier: NSColor] = [:]

    static func accent(for image: NSImage?) -> Color? {
        guard let image else { return nil }
        let key = ObjectIdentifier(image)
        if let cached = cache[key] {
            return Color(nsColor: cached)
        }
        guard let colour = sample(image) else { return nil }
        if cache.count > 24 { cache.removeAll() }
        cache[key] = colour
        return Color(nsColor: colour)
    }

    /// Weighted average of the most saturated pixels, then pushed to a hue that
    /// stays legible on the black island.
    private static func sample(_ image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else { return nil }

        let side = 12
        let bytesPerRow = side * 4
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: &pixels,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.interpolationQuality = .low
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: side, height: side)
        )

        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var weight = 0.0

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.15 else { continue }

            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255
            let high = max(r, g, b)
            let low = min(r, g, b)
            guard high > 0.08 else { continue }

            let saturation = (high - low) / high
            // Favour vivid mid-tones; near-black and blown-out pixels matter less.
            let tone = 1 - abs(high - 0.62) / 0.62
            let pixelWeight = (0.15 + saturation) * max(0.1, tone)
            red += r * pixelWeight
            green += g * pixelWeight
            blue += b * pixelWeight
            weight += pixelWeight
        }

        guard weight > 0 else { return nil }

        var colour = NSColor(
            srgbRed: red / weight,
            green: green / weight,
            blue: blue / weight,
            alpha: 1
        )

        if let rgb = colour.usingColorSpace(.deviceRGB) {
            var hue: CGFloat = 0
            var saturation: CGFloat = 0
            var brightness: CGFloat = 0
            var alpha: CGFloat = 0
            rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
            // Keep the artwork's hue but guarantee contrast on black.
            colour = NSColor(
                hue: hue,
                saturation: min(max(saturation, 0.45), 1),
                brightness: min(max(brightness, 0.72), 0.95),
                alpha: 1
            )
        }

        return colour
    }
}
