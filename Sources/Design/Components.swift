import SwiftUI
import AppKit

/// A compact slider with a thin track and a small thumb. The stock SwiftUI
/// slider is too tall and too loud for a 200pt island.
struct MiniSlider: View {
    @Binding var value: Double
    var tint: Color = .white
    var onEditingChanged: (Bool) -> Void = { _ in }

    @State private var dragging = false

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let clamped = min(max(value, 0), 1)
            let thumb: CGFloat = 9
            let travel = max(width - thumb, 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 3)
                Capsule()
                    .fill(tint)
                    .frame(width: max(3, width * clamped), height: 3)
                Circle()
                    .fill(tint)
                    .frame(width: thumb, height: thumb)
                    .offset(x: travel * clamped)
                    .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !dragging {
                            dragging = true
                            onEditingChanged(true)
                        }
                        value = min(max(gesture.location.x / width, 0), 1)
                    }
                    .onEnded { _ in
                        dragging = false
                        onEditingChanged(false)
                    }
            )
        }
        .frame(height: 16)
    }
}

/// Three tiny bars that breathe while audio is playing.
struct EqualizerBars: View {
    var active: Bool = true
    var color: Color = .white
    var count: Int = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    let phase = t * 2.4 + Double(index) * 1.15
                    let height = active ? 3 + 7 * abs(sin(phase)) : 3
                    Capsule()
                        .fill(color)
                        .frame(width: 2, height: height)
                }
            }
            .frame(width: CGFloat(count) * 4, height: 10)
        }
    }
}

/// Header button. Selected tabs get a white capsule with a black glyph, the
/// rest stay quiet until hovered.
struct IslandIconButton: View {
    let systemName: String
    var active: Bool = false
    var help: String = ""
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(active ? Color.black : (hovering ? Theme.text : Theme.secondary))
                .frame(width: 26, height: 23)
                .background(
                    Capsule()
                        .fill(active ? Color.white : (hovering ? Theme.fill : Color.clear))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

/// A one-line label used above panes ("TODAY", "7 DAYS").
struct MicroLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8.5, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Theme.tertiary)
    }
}

/// Hairline separator that matches the island surfaces.
struct IslandDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(height: 1)
    }
}

extension View {
    /// Shows a pointing hand for clickable rows without unbalancing the cursor
    /// stack when the pointer leaves quickly.
    func islandPointer() -> some View {
        self.onContinuousHover { phase in
            switch phase {
            case .active:
                NSCursor.pointingHand.set()
            case .ended:
                NSCursor.arrow.set()
            }
        }
    }
}

/// A springy press effect for transport, tab and action buttons.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.90

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(Theme.quick, value: configuration.isPressed)
    }
}

/// A tab button whose white selection pill slides between tabs.
struct IslandTabButton: View {
    let tab: IslandTab
    let active: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if active {
                    Capsule()
                        .fill(Color.white)
                        .matchedGeometryEffect(id: "island.selectedTab", in: namespace)
                        .frame(width: 26, height: 24)
                }
                Image(systemName: tab.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(active ? Color.black : (hovering ? Theme.text : Theme.secondary))
            }
            .frame(width: 26, height: 24)
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.92))
        .onHover { hovering = $0 }
        .help(tab.title)
    }
}

/// A tiny dot that breathes while the network is active.
struct PulseDot: View {
    var active: Bool
    var size: CGFloat = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.1, paused: !active)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.4) / 1.4
            ZStack {
                if active {
                    Circle()
                        .stroke(Color.white.opacity(0.35 * (1 - phase)), lineWidth: 0.6)
                        .frame(width: size, height: size)
                        .scaleEffect(1 + phase * 2.2)
                }
                Circle()
                    .fill(active ? Color.white : Theme.tertiary)
                    .frame(width: size, height: size)
            }
            .frame(width: size * 3.4, height: size * 3.4)
        }
    }
}
