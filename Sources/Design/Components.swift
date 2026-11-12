import SwiftUI
import AppKit

/// Compact on/off switch used by the connectivity pane.
struct IslandSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(isOn ? Theme.online : Color.white.opacity(0.16))
                .frame(width: 30, height: 16)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? Color.black.opacity(0.78) : Color.white.opacity(0.72))
                        .frame(width: 12, height: 12)
                        .padding(2)
                }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.92))
        .animation(Theme.quick, value: isOn)
        .accessibilityLabel(isOn ? "On" : "Off")
    }
}

/// A bar-style audio waveform like a real player visualizer. `active` freezes
/// it into a low row when paused.
struct PlayingWaveform: View {
    var active: Bool = true
    var color: Color = .white
    var barWidth: CGFloat = 2
    var gap: CGFloat = 1.8

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.06, paused: !active)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let count = max(3, Int((size.width + gap) / (barWidth + gap)))
                let totalWidth = CGFloat(count) * barWidth + CGFloat(count - 1) * gap
                let startX = (size.width - totalWidth) / 2

                for index in 0..<count {
                    let p = Double(index) / Double(max(count - 1, 1))
                    let phase = Double(index) * 0.85
                    let speed = 2.2 + Double(index % 4) * 0.45
                    let wave = 0.5 + 0.5 * sin(t * speed + phase)
                    let envelope = 0.55 + 0.45 * sin(p * .pi * 2.4 + t * 0.9)
                    let floor: Double = active ? 0.16 : 0.10
                    let fraction = active
                        ? floor + (1 - floor) * wave * envelope
                        : floor
                    let height = max(barWidth, size.height * fraction)
                    let rect = CGRect(
                        x: startX + CGFloat(index) * (barWidth + gap),
                        y: (size.height - height) / 2,
                        width: barWidth,
                        height: height
                    )
                    ctx.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(color.opacity(active ? 0.95 : 0.38))
                    )
                }
            }
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
        .accessibilityLabel(help.isEmpty ? systemName : help)
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
        .accessibilityLabel(tab.title)
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
