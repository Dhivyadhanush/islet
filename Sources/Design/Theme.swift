import SwiftUI

/// One place for the look. Islet is deliberately monochrome: black island,
/// white type, thin white surfaces. Nothing else competes with the content.
enum Theme {
    static let text = Color.white
    static let secondary = Color.white.opacity(0.58)
    static let tertiary = Color.white.opacity(0.34)
    static let hairline = Color.white.opacity(0.10)
    static let fill = Color.white.opacity(0.09)
    static let fillStrong = Color.white.opacity(0.16)

    static let spring = Animation.spring(response: 0.40, dampingFraction: 0.76)
    static var motion: Animation {
        if UserDefaults.standard.bool(forKey: Defaults.calmMotion) {
            return .spring(response: 0.46, dampingFraction: 0.95)
        }
        return .spring(response: 0.40, dampingFraction: 0.76)
    }
    static let content = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let quick = Animation.spring(response: 0.24, dampingFraction: 0.90)
    static let fade = Animation.easeOut(duration: 0.18)

    static let corner: CGFloat = 26
    static let mono = Font.system(size: 10, weight: .medium, design: .monospaced)
    static let micro = Font.system(size: 8.5, weight: .semibold, design: .rounded)
}
