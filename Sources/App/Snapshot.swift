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
        let network = NetworkMonitor()
        let controls = SystemControls()
        let calendar = CalendarService()
        let battery = BatteryMonitor()
        battery.previewSeed(percentage: 82, charging: true)

        let sample = sampleHistory()
        network.previewSeed(
            down: sample.last?.down ?? 0,
            up: sample.last?.up ?? 0,
            rate: 2_400_000,
            history: sample
        )
        controls.previewSeed(volume: 0.62, brightness: 0.78)
        calendar.previewSeed(status: .fullAccess, events: sampleEvents())

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
                .environmentObject(controls)
                .environmentObject(calendar)
                .environmentObject(battery)
        )

        // Collapsed: network.
        UserDefaults.standard.set("network", forKey: Defaults.compactSource)
        state.expanded = false
        render(root, size: state.geometry.collapsedSize, name: "01-collapsed-network", directory: directoryURL)

        // Collapsed: music.
        UserDefaults.standard.set("music", forKey: Defaults.compactSource)
        nowPlaying.previewSet(track, position: 43)
        render(root, size: state.geometry.collapsedSize, name: "02-collapsed-music", directory: directoryURL)

        // Collapsed: next event.
        UserDefaults.standard.set("calendar", forKey: Defaults.compactSource)
        render(root, size: state.geometry.collapsedSize, name: "03-collapsed-calendar", directory: directoryURL)

        UserDefaults.standard.set("auto", forKey: Defaults.compactSource)

        // Expanded panes.
        state.expanded = true
        let expanded = state.geometry.expandedSize

        state.tab = .music
        render(root, size: expanded, name: "04-expanded-music", directory: directoryURL)

        state.tab = .network
        render(root, size: expanded, name: "05-expanded-network", directory: directoryURL)

        state.tab = .controls
        render(root, size: expanded, name: "06-expanded-controls", directory: directoryURL)

        state.tab = .calendar
        render(root, size: expanded, name: "07-expanded-calendar", directory: directoryURL)

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
                title: "Ship Islet 0.1",
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
