import SwiftUI

/// The solo-island brand mark: a white island with a black notch and animated
/// equalizer bars. Used in Settings > About and anywhere the app wants a small
/// animated logo.
struct SoloIslandMark: View {
    var width: CGFloat = 150

    var body: some View {
        let height = width * 0.35
        let notchWidth = width * 0.30
        let notchHeight = height * 0.34

        ZStack {
            Capsule()
                .fill(Color.white)

            RoundedRectangle(cornerRadius: notchHeight * 0.40, style: .continuous)
                .fill(Color.black)
                .frame(width: notchWidth, height: notchHeight)
                .offset(y: -height / 2 + notchHeight * 0.35)

            TimelineView(.animation(minimumInterval: 0.12)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(alignment: .bottom, spacing: width * 0.018) {
                    ForEach(0..<3, id: \.self) { index in
                        let value = 0.18 + 0.12 * abs(sin(t * 2.4 + Double(index) * 1.1))
                        Capsule()
                            .fill(Color.black)
                            .frame(width: width * 0.032, height: height * value)
                    }
                }
                .offset(y: height * 0.10)
            }
        }
        .frame(width: width, height: height)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.22), radius: height * 0.12, y: height * 0.05)
        .accessibilityLabel("lost_Island")
    }
}
