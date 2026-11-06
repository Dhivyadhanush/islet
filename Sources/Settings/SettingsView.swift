import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var calendar: CalendarService
    @EnvironmentObject private var network: NetworkMonitor
    @EnvironmentObject private var nowPlaying: NowPlaying

    @AppStorage(Defaults.showMusic) private var showMusic = true
    @AppStorage(Defaults.showNetwork) private var showNetwork = true
    @AppStorage(Defaults.showControls) private var showControls = true
    @AppStorage(Defaults.showCalendar) private var showCalendar = true
    @AppStorage(Defaults.compactSource) private var compactSource = "auto"
    @AppStorage(Defaults.hoverExpand) private var hoverExpand = true
    @AppStorage(Defaults.calmMotion) private var calmMotion = false
    @AppStorage(Defaults.showBattery) private var showBattery = true

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                moduleRow(
                    icon: "music.note",
                    title: "Music",
                    subtitle: "Now playing, artwork and transport controls",
                    isOn: $showMusic
                )
                moduleRow(
                    icon: "arrow.up.arrow.down",
                    title: "Network",
                    subtitle: "Today's usage, live rate and a seven-day chart",
                    isOn: $showNetwork
                )
                moduleRow(
                    icon: "slider.horizontal.3",
                    title: "Controls",
                    subtitle: "Volume and display brightness",
                    isOn: $showControls
                )
                moduleRow(
                    icon: "calendar",
                    title: "Calendar",
                    subtitle: "Today's events and one-click meeting links",
                    isOn: $showCalendar
                )
            } header: {
                Text("Modules")
            } footer: {
                Text("Disabled modules disappear from the island and from its tab bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Compact view") {
                Picker("Show in the collapsed island", selection: $compactSource) {
                    Text("Auto").tag("auto")
                    Text("Music").tag("music")
                    Text("Network").tag("network")
                    Text("Calendar").tag("calendar")
                }
                .pickerStyle(.segmented)
                Text("Auto shows music while it plays, the next event within an hour, otherwise today's network total.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Expand on hover", isOn: $hoverExpand)
                Toggle("Show battery in the header", isOn: $showBattery)
                Toggle("Launch at login", isOn: $launchAtLogin)
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Motion") {
                Toggle("Calm animations", isOn: $calmMotion)
                Text("Calm uses a softer spring with less overshoot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Media") {
                HStack {
                    Label("Browser playback", systemImage: "safari")
                    Spacer()
                    Text(mediaStatus)
                        .foregroundStyle(.secondary)
                }
                Text("Safari, Chrome, Brave, Arc and Firefox report through the system now-playing service. Islet reads it locally; nothing is sent anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Network") {
                HStack {
                    Text("Today")
                    Spacer()
                    Text(ByteFormat.bytes(network.todayTotal))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button("Reset network history") {
                    network.reset()
                }
            }

            Section("Permissions") {
                HStack {
                    Label("Calendar", systemImage: "calendar")
                    Spacer()
                    Text(calendarStatus)
                        .foregroundStyle(.secondary)
                    if calendar.status == .notDetermined {
                        Button("Allow") { calendar.requestAccess() }
                    } else if calendar.status != .fullAccess {
                        Button("Open Settings") { openCalendarSettings() }
                    }
                }
                Text("Music and browsers need no permission. If macOS asks for Automation, allow it so Islet can read the current track.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text("Islet")
                    Spacer()
                    Text(version)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 700)
        .onChange(of: launchAtLogin) { _, enabled in
            do {
                try LaunchAtLogin.set(enabled)
                loginError = nil
            } catch {
                loginError = error.localizedDescription
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        }
    }

    private func moduleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }

    private var mediaStatus: String {
        if nowPlaying.bridgeActive { return "Connected" }
        if nowPlaying.usingFallback { return "Fallback" }
        return "Starting…"
    }

    private var calendarStatus: String {
        switch calendar.status {
        case .fullAccess: return "Allowed"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not requested"
        default: return "Unknown"
        }
    }

    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0"
        return "v\(short)"
    }

    private func openCalendarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
