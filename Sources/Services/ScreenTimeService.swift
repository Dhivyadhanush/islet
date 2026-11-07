import AppKit
import CoreGraphics
import Foundation

/// Local Screen Time estimate.
///
/// macOS does not expose system Screen Time totals to third-party apps without
/// Full Disk Access (the Knowledge database) or a DeviceActivity report
/// extension. This service tracks the frontmost app while Islet runs, excludes
/// idle/sleep time, and persists today's totals locally. The pane labels it as
/// a local estimate so it is never confused with Apple's number.
@MainActor
final class ScreenTimeService: ObservableObject {
    struct AppUsage: Identifiable {
        let id: String
        let name: String
        let seconds: TimeInterval
        let icon: NSImage?
    }

    @Published private(set) var todaySeconds: TimeInterval = 0
    @Published private(set) var apps: [AppUsage] = []
    @Published private(set) var hourly: [Double] = Array(repeating: 0, count: 24)
    @Published private(set) var trackingSince = Date()
    @Published private(set) var hasData = false

    private struct Archive: Codable {
        var day: String
        var total: Double
        var apps: [String: Double]
        var names: [String: String]
        var hourly: [Double]
        var since: Double
    }

    private let storeKey = "islet.screentime.v1"
    private var timer: Timer?
    private var lastTick = Date()
    private var currentDay = ""
    private var stored: [String: Double] = [:]
    private var names: [String: String] = [:]
    private var icons: [String: NSImage] = [:]
    private var hourlyStored: [Double] = Array(repeating: 0, count: 24)
    private var lastPersist = Date.distantPast

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func start() {
        guard timer == nil else { return }
        currentDay = Self.dayKey(Date())
        load()
        lastTick = Date()

        let t = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func flush() {
        persist()
    }

    func reset() {
        stored.removeAll()
        names.removeAll()
        icons.removeAll()
        hourlyStored = Array(repeating: 0, count: 24)
        todaySeconds = 0
        trackingSince = Date()
        hasData = false
        rebuildApps()
        persist()
    }

    /// Used by `--snapshot` to render sample data.
    func previewSeed(
        total: TimeInterval,
        apps: [AppUsage],
        hourly: [Double],
        since: Date
    ) {
        todaySeconds = total
        self.apps = apps
        self.hourly = hourly.count == 24 ? hourly : Array(repeating: 0, count: 24)
        trackingSince = since
        hasData = !apps.isEmpty
    }

    private func sample() {
        let now = Date()
        rolloverIfNeeded(now)

        let delta = now.timeIntervalSince(lastTick)
        lastTick = now
        guard delta > 0, delta < 60 else { return }
        guard CGDisplayIsAsleep(CGMainDisplayID()) == 0 else { return }

        let mouseIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        let keyIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        guard min(mouseIdle, keyIdle) < 600 else { return }

        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundle = app.bundleIdentifier else { return }
        guard !Self.isSystemUI(bundle) else { return }

        stored[bundle, default: 0] += delta
        names[bundle] = app.localizedName ?? bundle
        if let icon = app.icon { icons[bundle] = icon }

        let hour = Calendar.current.component(.hour, from: now)
        if hourlyStored.indices.contains(hour) {
            hourlyStored[hour] += delta
        }
        todaySeconds += delta
        hasData = true
        rebuildApps()

        if now.timeIntervalSince(lastPersist) > 20 {
            persist()
            lastPersist = now
        }
    }

    private func rebuildApps() {
        apps = stored.map { bundle, seconds in
            AppUsage(
                id: bundle,
                name: names[bundle] ?? bundle,
                seconds: seconds,
                icon: icons[bundle]
            )
        }
        .sorted { $0.seconds > $1.seconds }
        hourly = hourlyStored
    }

    private func rolloverIfNeeded(_ now: Date) {
        let key = Self.dayKey(now)
        guard key != currentDay else { return }
        currentDay = key
        stored.removeAll()
        names.removeAll()
        icons.removeAll()
        hourlyStored = Array(repeating: 0, count: 24)
        todaySeconds = 0
        trackingSince = now
        hasData = false
        rebuildApps()
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let archive = try? JSONDecoder().decode(Archive.self, from: data) else { return }
        guard archive.day == currentDay else { return }

        stored = archive.apps
        names = archive.names
        hourlyStored = archive.hourly.count == 24 ? archive.hourly : Array(repeating: 0, count: 24)
        todaySeconds = archive.total
        trackingSince = Date(timeIntervalSince1970: archive.since)
        hasData = archive.total > 0

        for bundle in stored.keys {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first {
                names[bundle] = app.localizedName ?? names[bundle]
                icons[bundle] = app.icon
            }
        }
        rebuildApps()
    }

    private func persist() {
        let archive = Archive(
            day: currentDay,
            total: todaySeconds,
            apps: stored,
            names: names,
            hourly: hourlyStored,
            since: trackingSince.timeIntervalSince1970
        )
        if let data = try? JSONEncoder().encode(archive) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static func isSystemUI(_ bundle: String) -> Bool {
        let excluded = [
            "dev.dhanuz.islet",
            "com.apple.loginwindow",
            "com.apple.ScreenSaver.Engine",
            "com.apple.dock",
            "com.apple.WindowManager",
            "com.apple.controlcenter",
            "com.apple.notificationcenterui",
        ]
        return excluded.contains(bundle)
    }
}
