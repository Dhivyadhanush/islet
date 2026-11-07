import SwiftUI

struct ServerPane: View {
    @EnvironmentObject private var server: ServerStatusService
    @EnvironmentObject private var state: IslandState

    @AppStorage(Defaults.serverCPU) private var showCPU = true
    @AppStorage(Defaults.serverRAM) private var showRAM = true
    @AppStorage(Defaults.serverDisk) private var showDisk = true
    @AppStorage(Defaults.serverNetwork) private var showNetwork = true

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                MicroLabel(text: "Server")
                Spacer()
                Text(headerStatus)
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

            if !server.systems.isEmpty {
                systemList
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

    private var systemList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(server.systems.enumerated()), id: \.element.id) { index, system in
                systemRow(system)
                if index < server.systems.count - 1 {
                    IslandDivider()
                        .padding(.vertical, 3)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                if let error = server.lastError, !error.isEmpty {
                    Text(error)
                        .lineLimit(1)
                } else {
                    Text("updated \(TimeText.short(server.lastUpdated ?? Date()))")
                    if server.isRefreshing {
                        Text("· updating…")
                    }
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: 8))
            .foregroundStyle(Theme.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func systemRow(_ system: BeszelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Circle()
                    .fill(system.isOnline ? Color.white : Theme.tertiary)
                    .frame(width: 4, height: 4)
                Text(system.name)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(hostLabel(system))
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }

            let items = metricItems(system)
            if !items.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        metric(item.0, item.1)
                        if index < items.count - 1 {
                            Spacer(minLength: 10)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 2)
    }

    private func metricItems(_ system: BeszelMetrics) -> [(String, String)] {
        var items: [(String, String)] = []
        if showCPU {
            items.append(("CPU", "\(Int(system.cpuPercent.rounded()))%"))
        }
        if showRAM {
            items.append(("RAM", "\(Int(system.memoryPercent.rounded()))%"))
        }
        if showDisk {
            items.append(("DISK", "\(Int(system.diskPercent.rounded()))%"))
        }
        if showNetwork {
            items.append(("NET", networkText(system)))
        }
        return items
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7.5, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(Theme.tertiary)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.text.opacity(0.9))
                .lineLimit(1)
        }
    }

    private func networkText(_ system: BeszelMetrics) -> String {
        let down = rate(system.networkReceivedBytesPerSecond)
        let up = rate(system.networkSentBytesPerSecond)
        let interface = system.primaryInterface
        let prefix = interface.isEmpty ? "" : "\(interface) "
        return "\(prefix)↓ \(down) ↑ \(up)"
    }

    private func rate(_ bytes: Double) -> String {
        if bytes >= 1_048_576 {
            return String(format: "%.1f MB/s", bytes / 1_048_576)
        }
        if bytes >= 1024 {
            let kilobytes = bytes / 1024
            if kilobytes >= 10 {
                return String(format: "%.0f KB/s", kilobytes)
            }
            return String(format: "%.1f KB/s", kilobytes)
        }
        return String(format: "%.0f B/s", bytes)
    }

    private func hostLabel(_ system: BeszelMetrics) -> String {
        let hostname = system.hostname.isEmpty ? system.name : system.hostname
        let host = system.host
        if host.isEmpty
            || host.hasPrefix("/")
            || host == hostname
            || host == "localhost"
            || host == "127.0.0.1" {
            return hostname
        }
        return "\(hostname) · \(host)"
    }

    private var headerStatus: String {
        if !server.systems.isEmpty {
            return "\(server.onlineCount)/\(server.systems.count) online"
        }
        switch server.status {
        case .notConfigured: return "not configured"
        case .checking: return "checking"
        case .online: return "online"
        case .offline: return "offline"
        case .error: return "offline"
        }
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
                    Text("Connect Beszel in Settings → Server to show CPU, RAM, disk and network here.")
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
}
