import SwiftUI

struct ControlsPane: View {
    @EnvironmentObject private var controls: SystemControls

    var body: some View {
        VStack(spacing: 15) {
            ControlRow(
                icon: "sun.min",
                label: "Brightness",
                subtitle: "Built-in display",
                value: Binding(
                    get: { controls.brightness },
                    set: { controls.setBrightness($0) }
                ),
                available: controls.brightnessAvailable,
                onEditing: { controls.setBrightnessEditing($0) }
            )

            ControlRow(
                icon: controls.muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: "Volume",
                subtitle: "System output",
                value: Binding(
                    get: { controls.volume },
                    set: { controls.setVolume($0) }
                ),
                available: true,
                muted: controls.muted,
                onMute: { controls.toggleMute() },
                onEditing: { controls.setVolumeEditing($0) }
            )

            Spacer(minLength: 0)
        }
        .padding(.top, 5)
    }
}

private struct ControlRow: View {
    let icon: String
    let label: String
    var subtitle: String = ""
    @Binding var value: Double
    let available: Bool
    var muted: Bool = false
    var onMute: (() -> Void)? = nil
    var onEditing: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 15)

                VStack(alignment: .leading, spacing: 0) {
                    Text(label)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 8.5))
                            .foregroundStyle(Theme.tertiary)
                    }
                }

                Spacer()

                Text(available ? "\(Int((value * 100).rounded()))%" : "—")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.tertiary)

                if let onMute {
                    Button(action: onMute) {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(muted ? Theme.text : Theme.tertiary)
                            .frame(width: 16, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.85))
                    .help(muted ? "Unmute" : "Mute")
                }
            }

            MiniSlider(
                value: $value,
                tint: .white,
                onEditingChanged: onEditing
            )
            .opacity(available ? 1 : 0.35)
            .disabled(!available)
        }
    }
}
