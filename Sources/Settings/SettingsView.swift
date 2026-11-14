import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var calendar: CalendarService
    @EnvironmentObject private var network: NetworkMonitor
    @EnvironmentObject private var screenTime: ScreenTimeService
    @EnvironmentObject private var server: ServerStatusService
    @EnvironmentObject private var nowPlaying: NowPlaying

    @State private var draft = SettingsDraft.load()

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
                    isOn: $draft.showMusic
                )
                moduleRow(
                    icon: "arrow.up.arrow.down",
                    title: "Network",
                    subtitle: "Today's usage, live rate and a seven-day chart",
                    isOn: $draft.showNetwork
                )
                moduleRow(
                    icon: "hourglass",
                    title: "Screen Time",
                    subtitle: "Today's frontmost-app time and top apps",
                    isOn: $draft.showScreenTime
                )
                moduleRow(
                    icon: "wifi",
                    title: "Connectivity",
                    subtitle: "Wi-Fi and Bluetooth",
                    isOn: $draft.showControls
                )
                moduleRow(
                    icon: "calendar",
                    title: "Calendar",
                    subtitle: "Today's events and one-click meeting links",
                    isOn: $draft.showCalendar
                )
                moduleRow(
                    icon: "server.rack",
                    title: "Server",
                    subtitle: "Beszel status, CPU, RAM, disk and network",
                    isOn: $draft.showServer
                )
            } header: {
                Text("Modules")
            } footer: {
                Text("Disabled modules disappear from the island and from its tab bar. Hover the notch to open the island; the collapsed state merges with the notch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Expand on hover", isOn: $draft.hoverExpand)
                Toggle("Show battery in the header", isOn: $draft.showBattery)
                Toggle("Start at login", isOn: $draft.startAtLogin)
                Text("Open islet automatically when you sign in to this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let loginError {
                    Text(loginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Motion") {
                Toggle("Calm animations", isOn: $draft.calmMotion)
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
                Text("Tracked locally while islet runs. macOS does not expose system Screen Time to third-party apps without Full Disk Access, so this is a local estimate, not Apple's number.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Server metrics") {
                Toggle("CPU", isOn: $draft.serverCPU)
                    .toggleStyle(.checkbox)
                Toggle("RAM", isOn: $draft.serverRAM)
                    .toggleStyle(.checkbox)
                Toggle("Disk", isOn: $draft.serverDisk)
                    .toggleStyle(.checkbox)
                Toggle("Network", isOn: $draft.serverNetwork)
                    .toggleStyle(.checkbox)
                Text("Only checked metrics appear in the Server tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Server (Beszel)") {
                TextField("Hub URL", text: $serverURL)
                    .textContentType(.URL)
                TextField("Read-only email", text: $serverEmail)
                    .textContentType(.username)
                HStack(spacing: 8) {
                    SecureField(
                        server.publicConfig.hasPassword
                            ? "Password (leave blank to keep)"
                            : "Password",
                        text: $serverPassword
                    )
                    Button("Paste") {
                        pastePassword()
                    }
                    .font(.caption)
                    .help("Paste the password from the clipboard")
                }
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

                Text("Create a read-only user in Beszel → Settings → Users. If Cloudflare Access protects the hub, create a service token and paste its Client ID and Secret here. The password and secret are stored locally in a 0600 file and never leave this Mac.")
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
                Text("Safari, Chrome, Brave, Arc and Firefox report through the system now-playing service. islet reads it locally; nothing is sent anywhere.")
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
                Text("Music and browsers need no permission. If macOS asks for Automation, allow it so islet can read the current track.")
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
                    Text("islet")
                    Spacer()
                    Text(version)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            saveBar
        }
        .frame(width: 520, height: 700)
        .onAppear {
            draft = .load()
            let config = server.publicConfig
            serverURL = config.baseURL
            serverEmail = config.email
            serverAccessID = config.accessClientID
        }
    }

    private var saveBar: some View {
        HStack(spacing: 10) {
            if let loginError {
                Text(loginError)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                Text("Changes apply when you save.")
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button("Revert") {
                draft = .load()
            }
            .disabled(draft == SettingsDraft.load())

            Button("Save") {
                saveDraft()
            }
            .keyboardShortcut("s", modifiers: .command)
            .buttonStyle(.borderedProminent)
        }
        .font(.callout)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func saveDraft() {
        draft.save()
        applyLoginSetting()

        // Close on success; stay open only when macOS needs the user to act.
        guard loginError == nil else { return }
        closeSettingsWindow()
    }

    private func closeSettingsWindow() {
        let window = NSApp.keyWindow
            ?? NSApp.windows.first { $0.title == "islet Settings" }
        window?.performClose(nil)
    }

    private func applyLoginSetting() {
        let desired = draft.startAtLogin
        guard desired != LaunchAtLogin.isRegistered else {
            loginError = nil
            return
        }
        do {
            try LaunchAtLogin.set(desired)
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            draft.startAtLogin = LaunchAtLogin.isRegistered
            return
        }
        if desired, LaunchAtLogin.statusText == "Waiting for approval" {
            loginError = "Approve islet in System Settings → General → Login Items."
        }
    }

    private func pastePassword() {
        if let text = NSPasteboard.general.string(forType: .string) {
            serverPassword = text
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
        case .online: return "\(server.onlineCount)/\(server.systems.count) online"
        case .offline: return "0/\(server.systems.count) online"
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
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.2"
        return "v\(short)"
    }

    private func openCalendarSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}

/// Editable copy of the preferences. Settings only touch `UserDefaults` when the
/// user presses Save, so a half-finished change never leaks into the island.
private struct SettingsDraft: Equatable {
    var showMusic = true
    var showNetwork = true
    var showScreenTime = true
    var showControls = true
    var showCalendar = true
    var showServer = true
    var hoverExpand = true
    var calmMotion = false
    var startAtLogin = false
    var showBattery = true
    var serverCPU = true
    var serverRAM = true
    var serverDisk = true
    var serverNetwork = true

    static func load() -> SettingsDraft {
        let defaults = UserDefaults.standard
        return SettingsDraft(
            showMusic: defaults.bool(forKey: Defaults.showMusic),
            showNetwork: defaults.bool(forKey: Defaults.showNetwork),
            showScreenTime: defaults.bool(forKey: Defaults.showScreenTime),
            showControls: defaults.bool(forKey: Defaults.showControls),
            showCalendar: defaults.bool(forKey: Defaults.showCalendar),
            showServer: defaults.bool(forKey: Defaults.showServer),
            hoverExpand: defaults.bool(forKey: Defaults.hoverExpand),
            calmMotion: defaults.bool(forKey: Defaults.calmMotion),
            startAtLogin: LaunchAtLogin.isRegistered,
            showBattery: defaults.bool(forKey: Defaults.showBattery),
            serverCPU: defaults.bool(forKey: Defaults.serverCPU),
            serverRAM: defaults.bool(forKey: Defaults.serverRAM),
            serverDisk: defaults.bool(forKey: Defaults.serverDisk),
            serverNetwork: defaults.bool(forKey: Defaults.serverNetwork)
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(showMusic, forKey: Defaults.showMusic)
        defaults.set(showNetwork, forKey: Defaults.showNetwork)
        defaults.set(showScreenTime, forKey: Defaults.showScreenTime)
        defaults.set(showControls, forKey: Defaults.showControls)
        defaults.set(showCalendar, forKey: Defaults.showCalendar)
        defaults.set(showServer, forKey: Defaults.showServer)
        defaults.set(hoverExpand, forKey: Defaults.hoverExpand)
        defaults.set(calmMotion, forKey: Defaults.calmMotion)
        defaults.set(showBattery, forKey: Defaults.showBattery)
        defaults.set(serverCPU, forKey: Defaults.serverCPU)
        defaults.set(serverRAM, forKey: Defaults.serverRAM)
        defaults.set(serverDisk, forKey: Defaults.serverDisk)
        defaults.set(serverNetwork, forKey: Defaults.serverNetwork)
    }
}
