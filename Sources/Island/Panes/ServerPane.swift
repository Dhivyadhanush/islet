import SwiftUI

struct ServerPane: View {
    @EnvironmentObject private var server: ServerStatusService
    @EnvironmentObject private var state: IslandState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                MicroLabel(text: "Server")
                Spacer()
                Circle()
                    .fill(dotColor)
                    .frame(width: 4, height: 4)
                Text(statusLabel)
                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.tertiary)
                Button {
                    server.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.tertiary)
                        .frame(width: 14, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.8))
                .help("Refresh now")
            }

            if let metrics = server.metrics {
                dashboard(metrics)
            } else {
                switch server.status {
                case .notConfigured:
                    placeholder
                case .error(let message):
                    errorState(message)
                default:
                    loadingState
                }
            }
        }
        .padding(.top, 1)
    }

    private func dashboard(_ metrics: BeszelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(metrics.name)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(metrics.hostname.isEmpty ? metrics.os : metrics.hostname)
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                metric(
                    label: "CPU",
                    value: metrics.cpuPercent,
                    detail: metrics.cores > 0 ? "\(metrics.cores) cores" : ""
                )
                metric(
                    label: "RAM",
                    value: metrics.memoryPercent,
                    detail: memoryDetail(metrics)
                )
                metric(
                    label: "Disk",
                    value: metrics.diskPercent,
                    detail: diskDetail(metrics)
                )
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                Text("up \(uptimeString(metrics.uptimeSeconds))")
                if !metrics.os.isEmpty {
                    Text("·")
                    Text(metrics.os).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(server.isRefreshing ? "updating…" : TimeText.short(server.lastUpdated ?? metrics.updatedAt))
            }
            .font(.system(size: 8.5))
            .foregroundStyle(Theme.tertiary)

            if let error = server.lastError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func metric(label: String, value: Double, detail: String) -> some View {
        let clamped = min(max(value / 100, 0), 1)
        return VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Theme.tertiary)
            Text("\(Int(value.rounded()))%")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.text)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 2.5)
                    Capsule()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(2, geo.size.width * clamped), height: 2.5)
                }
            }
            .frame(height: 2.5)
            Text(detail.isEmpty ? " " : detail)
                .font(.system(size: 8))
                .foregroundStyle(Theme.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.system(size: 23, weight: .light))
                    .foregroundStyle(Theme.tertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Server monitoring")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Connect Beszel in Settings → Server to show CPU, RAM, disk and uptime here.")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Button {
                state.openSettings?()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Cannot reach Beszel")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text(message)
                .font(.system(size: 9))
                .foregroundStyle(Theme.tertiary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    server.refresh()
                } label: {
                    Text("Retry")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    state.openSettings?()
                } label: {
                    Text("Settings")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(Theme.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Theme.fill))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var loadingState: some View {
        VStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
            Text("Connecting to Beszel…")
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var statusLabel: String {
        switch server.status {
        case .notConfigured: return "not configured"
        case .checking: return "checking"
        case .online: return "online"
        case .offline: return "offline"
        case .error: return "offline"
        }
    }

    private var dotColor: Color {
        switch server.status {
        case .online: return Color.white
        case .offline, .error: return Theme.tertiary
        default: return Theme.tertiary.opacity(0.6)
        }
    }

    private func uptimeString(_ seconds: Double) -> String {
        let total = Int(max(seconds, 0))
        if total >= 86_400 {
            return "\(total / 86_400)d \((total % 86_400) / 3_600)h"
        }
        if total >= 3_600 {
            return "\(total / 3_600)h \((total % 3_600) / 60)m"
        }
        return "\(max(1, total / 60))m"
    }

    private func memoryDetail(_ metrics: BeszelMetrics) -> String {
        guard let used = metrics.memoryUsedBytes,
              let total = metrics.memoryTotalBytes,
              total > 0
        else { return "" }
        return "\(gigabytes(used)) / \(gigabytes(total))"
    }

    private func diskDetail(_ metrics: BeszelMetrics) -> String {
        guard let used = metrics.diskUsedGB,
              let total = metrics.diskTotalGB,
              total > 0
        else { return "" }
        return String(format: "%.0f / %.0f GB", used, total)
    }

    private func gigabytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB]
        formatter.countStyle = .memory
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
