import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let calendar: CalendarService
    private let network: NetworkMonitor
    private let screenTime: ScreenTimeService
    private let server: ServerStatusService
    private let nowPlaying: NowPlaying

    init(
        calendar: CalendarService,
        network: NetworkMonitor,
        screenTime: ScreenTimeService,
        server: ServerStatusService,
        nowPlaying: NowPlaying
    ) {
        self.calendar = calendar
        self.network = network
        self.screenTime = screenTime
        self.server = server
        self.nowPlaying = nowPlaying
    }

    func show() {
        if window == nil {
            let root = SettingsView()
                .environmentObject(calendar)
                .environmentObject(network)
                .environmentObject(screenTime)
                .environmentObject(server)
                .environmentObject(nowPlaying)
            let hosting = NSHostingController(rootView: root)
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "islet Settings"
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.setContentSize(NSSize(width: 520, height: 700))
            newWindow.center()
            newWindow.isReleasedWhenClosed = false
            newWindow.titlebarAppearsTransparent = false
            window = newWindow
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
