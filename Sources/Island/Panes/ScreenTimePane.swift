import SwiftUI

struct ScreenTimePane: View {
    @EnvironmentObject private var screenTime: ScreenTimeService

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                MicroLabel(text: "Screen Time")
                Spacer()
                Text(screenTime.hasData ? "since \(TimeText.short(screenTime.trackingSince))" : "local estimate")
                    .font(Theme.mono)
                    .foregroundStyle(Theme.tertiary)
            }

            if screenTime.hasData {
                Text(ScreenTimeFormat.duration(screenTime.todaySeconds))
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text)

                stackedBar
                    .frame(height: 4)

                VStack(spacing: 2) {
                    ForEach(screenTime.apps.prefix(3)) { app in
                        appRow(app)
                    }
                }

                Spacer(minLength: 0)

                Text("Tracked by islet while it runs")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.tertiary.opacity(0.8))
            } else {
                emptyState
            }
        }
        .padding(.top, 1)
    }

    private var stackedBar: some View {
        let top = Array(screenTime.apps.prefix(3))
        let total = max(screenTime.todaySeconds, 1)

        return GeometryReader { geo in
            let spacing = CGFloat(max(top.count - 1, 0)) * 2
            let available = max(geo.size.width - spacing, 0)
            HStack(spacing: 2) {
                ForEach(Array(top.enumerated()), id: \.element.id) { index, app in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.white.opacity([0.9, 0.5, 0.24][min(index, 2)]))
                        .frame(width: max(3, available * app.seconds / total))
                }
            }
        }
    }

    private func appRow(_ app: ScreenTimeService.AppUsage) -> some View {
        HStack(spacing: 6) {
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.fill)
                }
            }
            .frame(width: 12, height: 12)

            Text(app.name)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.text.opacity(0.92))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(ScreenTimeFormat.compact(app.seconds))
                .font(Theme.mono)
                .foregroundStyle(Theme.tertiary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 5) {
            Image(systemName: "hourglass")
                .font(.system(size: 19, weight: .light))
                .foregroundStyle(Theme.tertiary)
            Text("No activity yet")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.text)
            Text("islet tracks the frontmost app locally while it runs.")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
