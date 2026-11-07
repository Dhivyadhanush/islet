import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = IslandState()
    private let nowPlaying = NowPlaying()
    private let network = NetworkMonitor()
    private let screenTime = ScreenTimeService()
    private let controls = SystemControls()
    private let calendar = CalendarService()
    private let battery = BatteryMonitor()
    private let server = ServerStatusService()

    private var controller: IslandController!
    private var settingsController: SettingsWindowController!
    private var statusItem: NSStatusItem?
    private var chipController: NowPlayingChipController!
    private var nowPlayingObserver: AnyCancellable?
    private var expandedObserver: AnyCancellable?
    private var showItem: NSMenuItem?
    private var loginItem: NSMenuItem?

    private var isDiagnose: Bool {
        CommandLine.arguments.contains("--diagnose")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Defaults.register()

        settingsController = SettingsWindowController(
            calendar: calendar,
            network: network,
            screenTime: screenTime,
            server: server,
            nowPlaying: nowPlaying
        )
        controller = IslandController(
            state: state,
            nowPlaying: nowPlaying,
            network: network,
            screenTime: screenTime,
            controls: controls,
            calendar: calendar,
            battery: battery,
            server: server
        )
        state.openSettings = { [weak self] in self?.openSettings() }
        chipController = NowPlayingChipController(state: state, nowPlaying: nowPlaying)

        if !isDiagnose {
            controller.show()
        }

        nowPlaying.start()
        network.start()
        screenTime.start()
        controls.start()
        calendar.start()
        battery.start()
        server.start()
        setupStatusItem()
        observeNowPlaying()

        if isDiagnose {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self else { exit(1) }
                print("network  \(ByteFormat.bytes(self.network.todayTotal)) today, \(ByteFormat.rate(self.network.rate))")
                print("screentime \(ScreenTimeFormat.duration(self.screenTime.todaySeconds)) today (local)")
                print("volume   \(Int((self.controls.volume * 100).rounded()))%\(self.controls.muted ? " muted" : "")")
                print("display  \(Int((self.controls.brightness * 100).rounded()))%")
                if let track = self.nowPlaying.track {
                    print("music    \(track.title) — \(track.artist) [\(track.isPlaying ? "playing" : "paused")] \(track.source)")
                } else {
                    print("music    nothing playing")
                }
                print("media    \(self.nowPlaying.bridgeActive ? "helper" : (self.nowPlaying.usingFallback ? "fallback" : "starting"))")
                print("battery  \(self.battery.percentage)%\(self.battery.charging ? " charging" : "")")
                print("server   \(self.server.status) (\(self.server.systems.count) systems)")
                if self.calendar.status == .fullAccess {
                    print("calendar \(self.calendar.events.count) events today")
                } else {
                    print("calendar access not granted")
                }
                self.screenTime.flush()
                self.network.flush()
                self.nowPlaying.stop()
                exit(0)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        screenTime.flush()
        network.flush()
        nowPlaying.stop()
        server.stop()
    }

    // MARK: - Now-playing chip

    /// The mini cover + waveform chip that sits left of the notch. It exists
    /// only while audio plays and the island is collapsed.
    private func observeNowPlaying() {
        guard !isDiagnose else { return }
        nowPlayingObserver = nowPlaying.$track
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshChip()
            }
        expandedObserver = state.$expanded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshChip()
            }
    }

    private func refreshChip() {
        chipController?.update(
            track: nowPlaying.track,
            islandVisible: controller.isVisible
        )
    }

    // MARK: - Status item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = BrandMark.statusImage()
        }

        let menu = NSMenu()

        let show = NSMenuItem(title: "Show Island", action: #selector(toggleIsland), keyEquivalent: "")
        show.target = self
        show.state = controller.isVisible ? .on : .off
        menu.addItem(show)
        showItem = show

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LaunchAtLogin.isEnabled ? .on : .off
        menu.addItem(login)
        loginItem = login

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit lost_Island", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func toggleIsland() {
        if controller.isVisible {
            controller.hide()
        } else {
            controller.show()
        }
        showItem?.state = controller.isVisible ? .on : .off
        refreshChip()
    }

    @objc func openSettings() {
        settingsController.show()
    }

    @objc private func toggleLogin() {
        do {
            try LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
            loginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
        } catch {
            NSSound.beep()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

@main
struct IsletMain {
    @MainActor
    static func main() {
        if CommandLine.arguments.contains("--version") {
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
            print("lost_Island \(version)")
            exit(0)
        }

        Defaults.register()

        if CommandLine.arguments.contains("--beszel-save") {
            let args = CommandLine.arguments
            func value(_ name: String) -> String {
                guard let index = args.firstIndex(of: name), args.count > index + 1 else { return "" }
                return args[index + 1]
            }
            ServerStatusService.saveConfig(
                baseURL: value("--beszel-url"),
                email: value("--beszel-email"),
                password: value("--beszel-password"),
                accessClientID: value("--beszel-access-id"),
                accessClientSecret: value("--beszel-access-secret")
            )
            print("beszel config saved")
            exit(0)
        }

        if CommandLine.arguments.contains("--beszel-test") {
            let env = ProcessInfo.processInfo.environment
            let config = BeszelConfig(
                baseURL: env["BESZEL_URL"] ?? "",
                email: env["BESZEL_EMAIL"] ?? "",
                password: env["BESZEL_PASSWORD"] ?? "",
                accessClientID: env["CF_ACCESS_CLIENT_ID"] ?? "",
                accessClientSecret: env["CF_ACCESS_CLIENT_SECRET"] ?? ""
            )
            Task {
                do {
                    let systems = try await BeszelClient().fetch(config: config)
                    for metrics in systems {
                        print("server   \(metrics.name) [\(metrics.status)]")
                        print("cpu      \(Int(metrics.cpuPercent))%")
                        print("ram      \(Int(metrics.memoryPercent))%")
                        print("disk     \(Int(metrics.diskPercent))%")
                        print("net      ↓ \(Int(metrics.networkReceivedBytesPerSecond)) B/s ↑ \(Int(metrics.networkSentBytesPerSecond)) B/s \(metrics.primaryInterface)")
                        print("uptime   \(Int(metrics.uptimeSeconds))s")
                    }
                    exit(0)
                } catch {
                    print("error: \(error.localizedDescription)")
                    exit(1)
                }
            }
            RunLoop.main.run()
        }

        if let index = CommandLine.arguments.firstIndex(of: "--snapshot") {
            let directory = CommandLine.arguments.count > index + 1
                ? CommandLine.arguments[index + 1]
                : "build/snapshots"
            _ = NSApplication.shared
            Snapshot.run(directory: directory)
            exit(0)
        }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        AppDelegateStore.shared = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// NSApplication keeps a weak delegate, so hold it for the lifetime of the run loop.
final class AppDelegateStore {
    static var shared: AppDelegate?
}
