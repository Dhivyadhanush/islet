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

        let state = IslandState()
        state.geometry = IslandGeometry(
            screenFrame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
            notchHeight: 37.5,
            notchWidth: 208
        )

        let nowPlaying = NowPlaying()
        let screenTime = ScreenTimeService()
        let controls = SystemControls()
        let calendar = CalendarService()
        let battery = BatteryMonitor()
        let server = ServerStatusService()

        battery.previewSeed(percentage: 82, charging: true)
        controls.previewSeed(volume: 0.62, brightness: 0.78)
        calendar.previewSeed(status: .fullAccess, events: sampleEvents())
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

        state.tab = .screenTime
        render(root, size: expanded, name: "02-expanded-screentime", directory: directoryURL)

        state.tab = .controls
        render(root, size: expanded, name: "03-expanded-controls", directory: directoryURL)

        state.tab = .calendar
        render(root, size: expanded, name: "04-expanded-calendar", directory: directoryURL)

        state.tab = .server
        render(root, size: expanded, name: "05-expanded-server", directory: directoryURL)

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
                title: "Ship Islet",
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
