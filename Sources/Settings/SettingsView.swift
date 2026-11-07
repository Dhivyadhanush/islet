import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var calendar: CalendarService
    @EnvironmentObject private var network: NetworkMonitor
    @EnvironmentObject private var screenTime: ScreenTimeService
    @EnvironmentObject private var server: ServerStatusService
    @EnvironmentObject private var nowPlaying: NowPlaying

    @AppStorage(Defaults.showMusic) private var showMusic = true
    @AppStorage(Defaults.showNetwork) private var showNetwork = true
    @AppStorage(Defaults.showScreenTime) private var showScreenTime = true
    @AppStorage(Defaults.showControls) private var showControls = true
    @AppStorage(Defaults.showCalendar) private var showCalendar = true
    @AppStorage(Defaults.showServer) private var showServer = true
    @AppStorage(Defaults.hoverExpand) private var hoverExpand = true
    @AppStorage(Defaults.calmMotion) private var calmMotion = false
    @AppStorage(Defaults.showBattery) private var showBattery = true

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var loginError: String?
    @State private var serverURL = ""
    @State private var serverEmail = ""
    @State private var serverPassword = ""
    @State private var serverAccessID = ""
    @State private var serverAccessSecret = ""

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
                    icon: "hourglass",
                    title: "Screen Time",
                    subtitle: "Today's frontmost-app time and top apps",
                    isOn: $showScreenTime
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
                moduleRow(
                    icon: "server.rack",
                    title: "Server",
                    subtitle: "Placeholder for your server-status integration",
                    isOn: $showServer
                )
            } header: {
                Text("Modules")
            } footer: {
                Text("Disabled modules disappear from the island and from its tab bar. Hover the notch to open the island; the collapsed state merges with the notch.")
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

            Section("Screen Time") {
                HStack {
                    Text("Today")
                    Spacer()
                    Text(ScreenTimeFormat.duration(screenTime.todaySeconds))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button("Reset screen time data") {
                    screenTime.reset()
                }
                Text("Tracked locally while lost_Island runs. macOS does not expose system Screen Time to third-party apps without Full Disk Access, so this is a local estimate, not Apple's number.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Server (Beszel)") {
                TextField("Hub URL", text: $serverURL)
                    .textContentType(.URL)
                TextField("Read-only email", text: $serverEmail)
                    .textContentType(.username)
                SecureField("Password (leave blank to keep)", text: $serverPassword)
                TextField("Cloudflare Access Client ID (optional)", text: $serverAccessID)
                SecureField("Access Client Secret (optional)", text: $serverAccessSecret)

                HStack {
                    Button("Save & Test") {
                        saveServer()
                    }
                    Button("Refresh") {
                        server.refresh()
                    }
                    Spacer()
                    Text(serverStatus)
                        .foregroundStyle(.secondary)
                }

                if let error = server.lastError, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("Create a read-only user in Beszel → Settings → Users. If Cloudflare Access protects the hub, create a service token and paste its Client ID and Secret here. The password and secret are stored in Keychain.")
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
                Text("Safari, Chrome, Brave, Arc and Firefox report through the system now-playing service. lost_Island reads it locally; nothing is sent anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                Text("Music and browsers need no permission. If macOS asks for Automation, allow it so lost_Island can read the current track.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Spacer()
                    SoloIslandMark(width: 150)
                    Spacer()
                }
                .padding(.vertical, 8)
                HStack {
                    Text("lost_Island")
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
        .onAppear {
            let config = server.publicConfig
            serverURL = config.baseURL
            serverEmail = config.email
            serverAccessID = config.accessClientID
        }
    }

    private func saveServer() {
        server.save(
            baseURL: serverURL,
            email: serverEmail,
            password: serverPassword,
            accessClientID: serverAccessID,
            accessClientSecret: serverAccessSecret
        )
        serverPassword = ""
        serverAccessSecret = ""
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

    private var serverStatus: String {
        switch server.status {
        case .notConfigured: return "Not configured"
        case .checking: return "Checking…"
        case .online: return "Online"
        case .offline: return "Offline"
        case .error: return "Error"
        }
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
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.5.0"
        return "v\(short)"
    }

    private func openCalendarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
