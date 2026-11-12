import AppKit
import SwiftUI

/// Pulls a usable accent colour out of album artwork.
///
/// The player tints its progress bar, play button, artwork glow and waveform
/// with this colour so each track brings its own palette. Sampling is done on a
/// tiny bitmap and cached per artwork image, so it is cheap enough to call from
/// `body`.
enum ArtworkPalette {
    private struct Entry {
        weak var image: NSImage?
        let colour: NSColor
    }

    private struct Bucket {
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        var weight = 0.0
    }

    private static var cache: [ObjectIdentifier: Entry] = [:]

    static func accent(for image: NSImage?) -> Color? {
        guard let image else { return nil }
        let key = ObjectIdentifier(image)
        if let entry = cache[key], entry.image === image {
            return Color(nsColor: entry.colour)
        }
        guard let colour = sample(image) else { return nil }
        if cache.count > 24 { cache.removeAll() }
        cache[key] = Entry(image: image, colour: colour)
        return Color(nsColor: colour)
    }

    /// Finds the dominant saturated hue, then averages the pixels that carry
    /// that hue. A plain RGB average mixes complementary colours into grey,
    /// which is why some colourful covers produced a colourless player.
    private static func sample(_ image: NSImage) -> NSColor? {
        guard let cgImage = image.cgImage(
            forProposedRect: nil,
            context: nil,
            hints: nil
        ) else { return nil }

        let side = 12
        let bytesPerRow = side * 4
        let count = side * side * 4
        let buffer = UnsafeMutableRawPointer.allocate(
            byteCount: count,
            alignment: 16
        )
        defer { buffer.deallocate() }
        buffer.initializeMemory(as: UInt8.self, repeating: 0, count: count)

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: buffer,
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

        let pixels = buffer.bindMemory(to: UInt8.self, capacity: count)
        var buckets = Array(repeating: Bucket(), count: 12)

        for index in stride(from: 0, to: count, by: 4) {
            let alpha = Double(pixels[index + 3]) / 255
            guard alpha > 0.15 else { continue }

            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255
            let high = max(r, g, b)
            let low = min(r, g, b)
            guard high > 0.08 else { continue }

            let delta = high - low
            let saturation = delta / high
            // Greys have no useful hue; let the player fall back to white.
            guard saturation > 0.12 else { continue }

            let hue: Double
            if high == r {
                hue = (60 * ((g - b) / delta)).truncatingRemainder(dividingBy: 360)
            } else if high == g {
                hue = 60 * (((b - r) / delta) + 2)
            } else {
                hue = 60 * (((r - g) / delta) + 4)
            }
            let degrees = hue < 0 ? hue + 360 : hue

            // Favour vivid mid-tones; near-black and blown-out pixels matter less.
            let tone = max(0.1, 1 - abs(high - 0.62) / 0.62)
            let weight = (0.15 + saturation) * tone
            let bucket = min(Int(degrees / 30), 11)
            buckets[bucket].red += r * weight
            buckets[bucket].green += g * weight
            buckets[bucket].blue += b * weight
            buckets[bucket].weight += weight
        }

        guard let best = buckets.max(by: { $0.weight < $1.weight }),
              best.weight > 0
        else { return nil }

        var colour = NSColor(
            srgbRed: best.red / best.weight,
            green: best.green / best.weight,
            blue: best.blue / best.weight,
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
