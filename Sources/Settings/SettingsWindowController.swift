import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let calendar: CalendarService
    private let network: NetworkMonitor
    private let nowPlaying: NowPlaying

    init(calendar: CalendarService, network: NetworkMonitor, nowPlaying: NowPlaying) {
        self.calendar = calendar
        self.network = network
        self.nowPlaying = nowPlaying
    }

    func show() {
        if window == nil {
            let root = SettingsView()
                .environmentObject(calendar)
                .environmentObject(network)
                .environmentObject(nowPlaying)
            let hosting = NSHostingController(rootView: root)
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = "Islet Settings"
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
