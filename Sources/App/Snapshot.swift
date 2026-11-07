import SwiftUI
import AppKit
import EventKit

/// `Islet --snapshot <dir>` renders the island offscreen so the design can be
/// reviewed (and documented) without Screen Recording permission.
@MainActor
enum Snapshot {
    static func run(directory: String) {
        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        for key in [Defaults.serverCPU, Defaults.serverRAM, Defaults.serverDisk, Defaults.serverNetwork] {
            UserDefaults.standard.set(true, forKey: key)
        }

        let state = IslandState()
        state.geometry = IslandGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
            notchHeight: 37.5,
            notchWidth: 208
        )

        let nowPlaying = NowPlaying()
        let network = NetworkMonitor()
        let screenTime = ScreenTimeService()
        let controls = SystemControls()
        let calendar = CalendarService()
        let battery = BatteryMonitor()
        let server = ServerStatusService()

        battery.previewSeed(percentage: 82, charging: true)
        controls.previewSeed(volume: 0.62, brightness: 0.78)
        calendar.previewSeed(status: .fullAccess, events: sampleEvents())
        server.previewSeed(systems: sampleSystems())
        let history = sampleHistory()
        network.previewSeed(
            down: history.last?.down ?? 0,
            up: history.last?.up ?? 0,
            rate: 2_400_000,
            history: history
        )
        screenTime.previewSeed(
            total: 2 * 3600 + 22 * 60,
            apps: sampleApps(),
            hourly: sampleHours(),
            since: Date().addingTimeInterval(-3 * 3600)
        )

        let track = NowPlaying.Track(
            title: "Strawberry Milkshakes",
            artist: "Aro",
            album: "Strawberry Milkshakes",
            duration: 218,
            elapsed: 43,
            rate: 1,
            artwork: nil,
            source: "Music",
            sourceIcon: nil
        )

        let root = AnyView(
            IslandRootView()
                .environmentObject(state)
                .environmentObject(nowPlaying)
                .environmentObject(network)
                .environmentObject(screenTime)
                .environmentObject(controls)
                .environmentObject(calendar)
                .environmentObject(battery)
                .environmentObject(server)
        )

        // The collapsed state is the notch silhouette; useful as a sanity check.
        state.expanded = false
        render(root, size: state.geometry.collapsedSize, name: "00-collapsed-notch", directory: directoryURL)

        state.expanded = true
        let expanded = state.geometry.expandedSize

        nowPlaying.previewSet(track, position: 43)
        state.tab = .music
        render(root, size: expanded, name: "01-expanded-music", directory: directoryURL)

        state.tab = .network
        render(root, size: expanded, name: "02-expanded-network", directory: directoryURL)

        state.tab = .screenTime
        render(root, size: expanded, name: "03-expanded-screentime", directory: directoryURL)

        state.tab = .controls
        render(root, size: expanded, name: "04-expanded-controls", directory: directoryURL)

        state.tab = .calendar
        render(root, size: expanded, name: "05-expanded-calendar", directory: directoryURL)

        state.tab = .server
        render(root, size: expanded, name: "06-expanded-server", directory: directoryURL)

        print("Snapshots written to \(directoryURL.path)")
    }

    private static func render(_ view: AnyView, size: CGSize, name: String, directory: URL) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 2
        renderer.isOpaque = false
        guard let image = renderer.cgImage else {
            print("Could not render \(name)")
            return
        }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let data = bitmap.representation(using: .png, properties: [:]) else { return }
        let url = directory.appendingPathComponent("\(name).png")
        try? data.write(to: url)
        print("wrote \(name).png")
    }

    private static func sampleHistory() -> [NetworkMonitor.DayUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let values: [(UInt64, UInt64)] = [
            (2_100_000_000, 240_000_000),
            (800_000_000, 90_000_000),
            (3_400_000_000, 410_000_000),
            (1_200_000_000, 130_000_000),
            (2_800_000_000, 300_000_000),
            (900_000_000, 110_000_000),
            (1_100_000_000, 120_000_000),
        ]
        return (0..<7).compactMap { index in
            guard let date = calendar.date(byAdding: .day, value: index - 6, to: today) else { return nil }
            return NetworkMonitor.DayUsage(
                key: "sample-\(index)",
                date: date,
                down: values[index].0,
                up: values[index].1
            )
        }
    }

    private static func sampleSystems() -> [BeszelMetrics] {
        [
            BeszelMetrics(
                id: "sample-server1",
                name: "Server1",
                hostname: "server",
                host: "/beszel_socket/beszel.sock",
                status: "up",
                cpuPercent: 4,
                memoryPercent: 27,
                memoryUsedBytes: 1_932_735_283,
                memoryTotalBytes: 7_194_048_563,
                diskPercent: 22,
                diskUsedGB: 21,
                diskTotalGB: 98,
                networkSentBytesPerSecond: 1511,
                networkReceivedBytesPerSecond: 1064,
                interfaces: ["eth0", "tailscale0"],
                uptimeSeconds: 8 * 86_400 + 11 * 3_600,
                cores: 4,
                threads: 4,
                model: "AMD PRO A4-3350B APU",
                os: "Ubuntu 24.04.5 LTS",
                updatedAt: Date()
            ),
            BeszelMetrics(
                id: "sample-pi",
                name: "Raspberry Pi",
                hostname: "Rasberry",
                host: "192.168.1.19",
                status: "up",
                cpuPercent: 30,
                memoryPercent: 21,
                memoryUsedBytes: 205_520_896,
                memoryTotalBytes: 964_689_920,
                diskPercent: 10,
                diskUsedGB: 2.8,
                diskTotalGB: 29,
                networkSentBytesPerSecond: 2943,
                networkReceivedBytesPerSecond: 2523,
                interfaces: ["wlan0", "eth0", "tailscale0"],
                uptimeSeconds: 1 * 86_400 + 16 * 3_600,
                cores: 4,
                threads: 4,
                model: "ARMv7",
                os: "Raspbian 13",
                updatedAt: Date()
            ),
        ]
    }

    private static func sampleApps() -> [ScreenTimeService.AppUsage] {
        [
            ScreenTimeService.AppUsage(
                id: "com.apple.dt.Xcode",
                name: "Xcode",
                seconds: 3600 + 12 * 60,
                icon: NSImage(systemSymbolName: "hammer.fill", accessibilityDescription: nil)
            ),
            ScreenTimeService.AppUsage(
                id: "com.apple.Safari",
                name: "Safari",
                seconds: 48 * 60,
                icon: NSImage(systemSymbolName: "safari.fill", accessibilityDescription: nil)
            ),
            ScreenTimeService.AppUsage(
                id: "com.apple.Terminal",
                name: "Terminal",
                seconds: 22 * 60,
                icon: NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil)
            ),
        ]
    }

    private static func sampleHours() -> [Double] {
        var hours = Array(repeating: 0.0, count: 24)
        let now = Calendar.current.component(.hour, from: Date())
        for offset in 0..<4 {
            let hour = (now - offset + 24) % 24
            hours[hour] = Double(600 + offset * 900)
        }
        return hours
    }

    private static func sampleEvents() -> [CalendarService.EventItem] {
        let now = Date()
        func offset(_ minutes: Double) -> Date {
            now.addingTimeInterval(minutes * 60)
        }
        return [
            CalendarService.EventItem(
                id: "sample-1",
                title: "Design review",
                start: offset(-15),
                end: offset(20),
                isAllDay: false,
                calendarName: "Work",
                location: "Studio",
                color: .systemBlue,
                url: URL(string: "https://meet.google.com/abc-defg-hij")
            ),
            CalendarService.EventItem(
                id: "sample-2",
                title: "Lunch with Ana",
                start: offset(120),
                end: offset(165),
                isAllDay: false,
                calendarName: "Personal",
                location: "Kaffa",
                color: .systemOrange,
                url: nil
            ),
            CalendarService.EventItem(
                id: "sample-3",
                title: "Ship lost_Island",
                start: offset(240),
                end: offset(285),
                isAllDay: false,
                calendarName: "Work",
                location: nil,
                color: .systemPurple,
                url: nil
            ),
        ]
    }
}
