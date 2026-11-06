import SwiftUI
import AppKit

struct CalendarPane: View {
    @EnvironmentObject private var calendar: CalendarService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                MicroLabel(text: "Today")
                Spacer()
                Text(TimeText.weekdayDate.string(from: Date()))
                    .font(Theme.mono)
                    .foregroundStyle(Theme.tertiary)
            }

            switch calendar.status {
            case .fullAccess:
                if calendar.events.isEmpty {
                    emptyState
                } else {
                    eventList
                }
            case .notDetermined:
                permissionState(
                    title: "Calendar access needed",
                    subtitle: "Show today's events in the island.",
                    button: "Connect"
                ) {
                    calendar.requestAccess()
                }
            default:
                permissionState(
                    title: "Calendar access is off",
                    subtitle: "Allow access in System Settings to see events.",
                    button: "Open Settings"
                ) {
                    openCalendarSettings()
                }
            }
        }
        .padding(.top, 1)
    }

    private var eventList: some View {
        let visible = Array(calendar.events.prefix(4))
        let remaining = calendar.events.count - visible.count

        return VStack(alignment: .leading, spacing: 1) {
            ForEach(visible) { event in
                eventRow(event)
            }
            if remaining > 0 {
                Text("+\(remaining) more")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                    .padding(.leading, 58)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func eventRow(_ event: CalendarService.EventItem) -> some View {
        let now = Date()
        let isNow = !event.isAllDay && event.start <= now && event.end > now

        return HStack(alignment: .top, spacing: 8) {
            Text(event.isAllDay ? "All day" : TimeText.short(event.start))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(isNow ? Theme.text : Theme.tertiary)
                .frame(width: 48, alignment: .leading)

            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(Color(nsColor: event.color))
                .frame(width: 2.5)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.text.opacity(0.94))
                    .lineLimit(1)
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if let url = event.url, !event.isAllDay,
               isNow || event.start.timeIntervalSinceNow < 600 {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Text("Join")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(PressableButtonStyle())
                .help(url.absoluteString)
                .padding(.top, 1)
            } else if isNow {
                Text("NOW")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(.white))
                    .padding(.top, 1)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Theme.tertiary)
            Text("No events today")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func permissionState(
        title: String,
        subtitle: String,
        button: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.text)
            Text(subtitle)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiary)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(button)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openCalendarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
