import AppKit

/// Everything the island needs to know about the screen it lives on.
struct IslandGeometry {
    var screenFrame: CGRect = .zero
    var notchHeight: CGFloat = 0
    var notchWidth: CGFloat = 0

    var hasNotch: Bool { notchHeight > 0.5 && notchWidth > 40 }

    var collapsedSize: CGSize {
        if hasNotch {
            return CGSize(
                width: min(notchWidth + 72, screenFrame.width - 40),
                height: notchHeight + 26
            )
        }
        return CGSize(width: 248, height: 34)
    }

    var expandedSize: CGSize {
        CGSize(
            width: min(424, screenFrame.width - 40),
            height: hasNotch ? notchHeight + 204 : 232
        )
    }

    /// The island hangs from the top edge on notched Macs so it merges with the
    /// cutout. Without a notch it becomes a floating pill with rounded corners.
    var topRadius: CGFloat { hasNotch ? 0 : 18 }
    var bottomRadius: CGFloat { hasNotch ? 26 : 17 }

    static func read(from screen: NSScreen) -> IslandGeometry {
        let top = screen.safeAreaInsets.top
        let left = screen.auxiliaryTopLeftArea?.width ?? 0
        let right = screen.auxiliaryTopRightArea?.width ?? 0
        let width = screen.frame.width - left - right
        let notched = top > 0.5 && width > 40 && width < screen.frame.width * 0.6
        return IslandGeometry(
            screenFrame: screen.frame,
            notchHeight: notched ? top : 0,
            notchWidth: notched ? width : 0
        )
    }
}
