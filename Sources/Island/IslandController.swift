import AppKit
import SwiftUI

/// Owns the panel, its geometry and the hover/expand lifecycle.
@MainActor
final class IslandController {
    private let state: IslandState
    private let panel: IslandPanel
    private let nowPlaying: NowPlaying
    private let network: NetworkMonitor
    private let screenTime: ScreenTimeService
    private let connectivity: ConnectivityService
    private let calendar: CalendarService
    private let battery: BatteryMonitor
    private let server: ServerStatusService

    private var expandWork: DispatchWorkItem?
    private var collapseWork: DispatchWorkItem?
    private var shrinkWork: DispatchWorkItem?
    private var clickMonitor: Any?
    private var screenObserver: NSObjectProtocol?

    init(
        state: IslandState,
        nowPlaying: NowPlaying,
        network: NetworkMonitor,
        screenTime: ScreenTimeService,
        connectivity: ConnectivityService,
        calendar: CalendarService,
        battery: BatteryMonitor,
        server: ServerStatusService
    ) {
        self.state = state
        self.nowPlaying = nowPlaying
        self.network = network
        self.screenTime = screenTime
        self.connectivity = connectivity
        self.calendar = calendar
        self.battery = battery
        self.server = server
        self.panel = IslandPanel()

        let geometry = IslandGeometry.read(from: Self.preferredScreen())
        state.geometry = geometry

        let root = AnyView(
            IslandRootView()
                .environmentObject(state)
                .environmentObject(nowPlaying)
                .environmentObject(network)
                .environmentObject(screenTime)
                .environmentObject(connectivity)
                .environmentObject(calendar)
                .environmentObject(battery)
                .environmentObject(server)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        )
        let hosting = IslandHostingView(rootView: root)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting

        position(size: geometry.collapsedSize, geometry: geometry)

        state.onHover = { [weak self] inside in self?.hoverChanged(inside) }
        state.onExpandNow = { [weak self] in self?.expand() }
        state.onTogglePin = { [weak self] in self?.togglePin() }

        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state.expanded, !self.state.pinned else { return }
                self.collapse()
            }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reposition() }
        }
    }

    deinit {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    // MARK: - Visibility

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    func hide() {
        shrinkWork?.cancel()
        state.expanded = false
        state.pinned = false
        position(size: state.geometry.collapsedSize, geometry: state.geometry)
        panel.orderOut(nil)
    }

    var isVisible: Bool { panel.isVisible }

    // MARK: - Expansion

    func hoverChanged(_ inside: Bool) {
        state.hovered = inside
        expandWork?.cancel()
        collapseWork?.cancel()

        if inside {
            let hoverEnabled = UserDefaults.standard.object(forKey: Defaults.hoverExpand) as? Bool ?? true
            guard hoverEnabled else { return }
            let work = DispatchWorkItem { [weak self] in self?.expand() }
            expandWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
        } else if !state.pinned {
            let work = DispatchWorkItem { [weak self] in
                guard let self, !self.state.hovered, !self.state.pinned else { return }
                self.collapse()
            }
            collapseWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
        }
    }

    func expand() {
        guard !state.expanded else { return }
        shrinkWork?.cancel()
        position(size: state.geometry.expandedSize, geometry: state.geometry)
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        withAnimation(Theme.motion) {
            state.expanded = true
        }
    }

    func collapse() {
        guard state.expanded else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)

        let work = DispatchWorkItem { [weak self] in self?.shrinkIfPossible() }
        shrinkWork = work
        withAnimation(Theme.motion, completionCriteria: .logicallyComplete) {
            state.expanded = false
        } completion: {
            work.cancel()
            self.shrinkIfPossible()
        }
        // Safety net in case the completion is skipped (Reduce Motion, etc.).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: work)
    }

    private func shrinkIfPossible() {
        guard !state.expanded, isVisible else { return }
        position(size: state.geometry.collapsedSize, geometry: state.geometry)
    }

    func togglePin() {
        state.pinned.toggle()
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        if state.pinned {
            expand()
        } else if !state.hovered {
            collapse()
        }
    }

    // MARK: - Geometry

    private func reposition() {
        let geometry = IslandGeometry.read(from: Self.preferredScreen())
        state.geometry = geometry
        let size = state.expanded ? geometry.expandedSize : geometry.collapsedSize
        position(size: size, geometry: geometry)
    }

    private func position(size: CGSize, geometry: IslandGeometry) {
        // Ten points of transparent room on each side and below let the spring
        // overshoot without clipping against the window edge. The top edge
        // stays flush with the screen.
        let window = CGSize(width: size.width + 20, height: size.height + 10)
        let frame = NSRect(
            x: geometry.screenFrame.midX - window.width / 2,
            y: geometry.screenFrame.maxY - window.height,
            width: window.width,
            height: window.height
        )
        panel.setFrame(frame, display: true)
    }

    private static func preferredScreen() -> NSScreen {
        if let notched = NSScreen.screens.first(where: {
            $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil
        }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }
}
