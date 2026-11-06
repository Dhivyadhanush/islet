import SwiftUI

/// The always-visible line under the notch. One piece of information at a
/// time: music while it plays, the next meeting when it is close, otherwise
/// today's network total.
struct CompactView: View {
    @EnvironmentObject private var state: IslandState
    @EnvironmentObject private var nowPlaying: NowPlaying
    @EnvironmentObject private var network: NetworkMonitor
    @EnvironmentObject private var calendar: CalendarService

    @AppStorage(Defaults.showMusic) private var showMusic = true
    @AppStorage(Defaults.showNetwork) private var showNetwork = true
    @AppStorage(Defaults.showCalendar) private var showCalendar = true
    @AppStorage(Defaults.compactSource) private var compactSource = "auto"

    private enum Mode { case music, network, calendar, none }

    var body: some View {
        VStack(spacing: 0) {
            if state.geometry.hasNotch {
                Color.clear.frame(height: state.geometry.notchHeight)
            }

            HStack(spacing: 6) {
                icon
                Text(label)
                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.92))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 14)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch mode {
        case .music:
            if nowPlaying.track?.isPlaying == true {
                EqualizerBars(active: true)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
        case .network:
            Image(systemName: "arrow.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.secondary)
        case .calendar:
            Image(systemName: "calendar")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.secondary)
        case .none:
            Image(systemName: "capsule.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.tertiary)
        }
    }

    private var label: String {
        switch mode {
        case .music:
            return nowPlaying.track?.title ?? "Nothing playing"
        case .network:
            return "\(ByteFormat.bytes(network.todayTotal)) today"
        case .calendar:
            guard let event = calendar.nextEvent else { return "No events today" }
            if event.start <= Date() && event.end > Date() {
                return "Now · \(event.title)"
            }
            return "\(TimeText.relative(to: event.start)) · \(event.title)"
        case .none:
            return "Islet"
        }
    }

    private var mode: Mode {
        switch compactSource {
        case "music":
            if showMusic { return .music }
        case "network":
            if showNetwork { return .network }
        case "calendar":
            if showCalendar { return .calendar }
        default:
            break
        }
        return automaticMode
    }

    private var automaticMode: Mode {
        if showMusic, nowPlaying.track?.isPlaying == true { return .music }
        if showCalendar,
           let event = calendar.nextEvent,
           event.start.timeIntervalSinceNow < 3600 {
            return .calendar
        }
        if showNetwork { return .network }
        if showMusic { return .music }
        if showCalendar { return .calendar }
        return .none
    }
}
