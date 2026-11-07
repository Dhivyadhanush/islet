import SwiftUI

struct ServerPane: View {
    @EnvironmentObject private var server: ServerStatusService
    @EnvironmentObject private var state: IslandState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                MicroLabel(text: "Server")
                Spacer()
                Text(statusLabel)
                    .font(Theme.mono)
                    .foregroundStyle(Theme.tertiary)
            }

            switch server.status {
            case .notConfigured:
                placeholder
            case .checking:
                statusLine(title: "Checking…", subtitle: "Waiting for the server to answer.", color: Theme.secondary)
            case .online(let latency):
                statusLine(
                    title: "Online",
                    subtitle: "\(server.name) answered in \(latency) ms.",
                    color: Theme.text
                )
            case .offline:
                statusLine(
                    title: "Offline",
                    subtitle: "\(server.name) did not answer.",
                    color: Theme.text
                )
            }
        }
        .padding(.top, 1)
    }

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.system(size: 23, weight: .light))
                    .foregroundStyle(Theme.tertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Waiting for integration")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Text("Tell Islet how to reach your server and this tab will show uptime, latency and services.")
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

    private func statusLine(title: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(Theme.tertiary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusLabel: String {
        switch server.status {
        case .notConfigured: return "not configured"
        case .checking: return "checking"
        case .online(_): return "online"
        case .offline: return "offline"
        }
    }
}
