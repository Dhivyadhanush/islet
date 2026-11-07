import AppKit

/// Menu bar artwork: the island silhouette as a template image, so macOS can
/// tint it for light/dark menu bars.
enum BrandMark {
    static func statusImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let pill = NSRect(x: 1, y: 4.5, width: 16, height: 9)
            let path = NSBezierPath(roundedRect: pill, xRadius: 4.5, yRadius: 4.5)
            NSColor.black.setFill()
            path.fill()

            // Cut the notch out of the silhouette.
            let notch = NSRect(x: 6.2, y: 10.2, width: 5.6, height: 3.8)
            let notchPath = NSBezierPath(roundedRect: notch, xRadius: 1.2, yRadius: 1.2)
            NSGraphicsContext.current?.saveGraphicsState()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSColor.white.setFill()
            notchPath.fill()
            NSGraphicsContext.current?.restoreGraphicsState()
            return true
        }
        image.isTemplate = true
        return image
    }
}
