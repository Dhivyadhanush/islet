import SwiftUI

struct NetworkPane: View {
    @EnvironmentObject private var network: NetworkMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                MicroLabel(text: "Today")
                Spacer()
                liveRate
            }

            Text(ByteFormat.bytes(network.todayTotal))
                .font(.system(size: 29, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.text)

            HStack(spacing: 14) {
                Label(ByteFormat.bytes(network.todayDown), systemImage: "arrow.down")
                Label(ByteFormat.bytes(network.todayUp), systemImage: "arrow.up")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.secondary)

            Spacer(minLength: 2)
            weekChart
        }
        .padding(.top, 1)
    }
    private var liveRate: some View {
        HStack(spacing: 2) {
            PulseDot(active: network.rate > 1024)
            Text(ByteFormat.rate(network.rate))
                .font(Theme.mono)
                .foregroundStyle(Theme.tertiary)
        }
    }

    private var weekChart: some View {
        let peak = max(network.history.map(\.total).max() ?? 0, 1)
        let todayKey = network.history.last?.key

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(network.history) { day in
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(day.key == todayKey ? Color.white.opacity(0.9) : Color.white.opacity(0.18))
                        .frame(width: 13, height: barHeight(day, peak: peak))
                    Text(TimeText.dayLetter.string(from: day.date))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(day.key == todayKey ? Theme.text : Theme.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 50, alignment: .bottom)
    }

    private func barHeight(_ day: NetworkMonitor.DayUsage, peak: UInt64) -> CGFloat {
        guard peak > 0 else { return 3 }
        return 3 + 32 * CGFloat(Double(day.total) / Double(peak))
    }
}
