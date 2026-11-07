import SwiftUI

/// A notch-friendly shape whose top and bottom radii can animate. The collapsed
/// state matches the notch silhouette (square top, softly rounded bottom); the
/// expanded state keeps the square top and rounds the bottom card.
struct IslandShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let limit = min(rect.width, rect.height) / 2
        let top = min(max(topRadius, 0), limit)
        let bottom = min(max(bottomRadius, 0), limit)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY))
        if top > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + top),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottom))
        if bottom > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - bottom, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        }
        path.addLine(to: CGPoint(x: rect.minX + bottom, y: rect.maxY))
        if bottom > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - bottom),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + top))
        if top > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + top, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }
        path.closeSubpath()
        return path
    }
}
