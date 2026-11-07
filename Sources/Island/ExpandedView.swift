import SwiftUI

/// The expanded card: a row of module tabs and one focused pane.
struct ExpandedView: View {
    @EnvironmentObject private var state: IslandState
    @EnvironmentObject private var battery: BatteryMonitor

    @AppStorage(Defaults.showMusic) private var showMusic = true
    @AppStorage(Defaults.showScreenTime) private var showScreenTime = true
    @AppStorage(Defaults.showControls) private var showControls = true
    @AppStorage(Defaults.showCalendar) private var showCalendar = true
    @AppStorage(Defaults.showServer) private var showServer = true
    @AppStorage(Defaults.showBattery) private var showBattery = true

    @Namespace private var tabNamespace

    var body: some View {
        VStack(spacing: 0) {
            if state.geometry.hasNotch {
                Color.clear.frame(height: state.geometry.notchHeight)
            }
            header
            pane
        }
        .onAppear { ensureValidTab() }
        .onChange(of: tabs) { _, _ in ensureValidTab() }
    }

    private var tabs: [IslandTab] {
        var result: [IslandTab] = []
        if showMusic { result.append(.music) }
        if showScreenTime { result.append(.screenTime) }
        if showControls { result.append(.controls) }
        if showCalendar { result.append(.calendar) }
        if showServer { result.append(.server) }
        return result
    }

    private var header: some View {
        HStack(spacing: 4) {
            ForEach(tabs) { tab in
                IslandTabButton(
                    tab: tab,
                    active: state.tab == tab,
                    namespace: tabNamespace
                ) {
                    withAnimation(Theme.quick) {
                        state.tab = tab
                    }
                }
            }

            Spacer(minLength: 6)

            if showBattery && battery.available {
                HStack(spacing: 3) {
                    Image(systemName: battery.charging ? "bolt.fill" : batterySymbol)
                        .font(.system(size: 9, weight: .semibold))
                    Text("\(battery.percentage)%")
                        .monospacedDigit()
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(battery.percentage <= 20 ? Theme.text : Theme.tertiary)
                .padding(.trailing, 2)
                .help(battery.charging ? "Charging" : "Battery")
            }

            IslandIconButton(
                systemName: state.pinned ? "pin.fill" : "pin",
                active: state.pinned,
                help: state.pinned ? "Unpin" : "Keep open"
            ) {
                state.onTogglePin?()
            }
            IslandIconButton(systemName: "gearshape", help: "Settings") {
                state.openSettings?()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .frame(height: 38)
    }

    @ViewBuilder
    private var pane: some View {
        if tabs.isEmpty {
            emptyState
        } else {
            Group {
                switch state.tab {
                case .music: MusicPane()
                case .screenTime: ScreenTimePane()
                case .controls: ControlsPane()
                case .calendar: CalendarPane()
                case .server: ServerPane()
                }
            }
            .id(state.tab)
            .transition(.opacity)
            .animation(Theme.fade, value: state.tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Image(systemName: "capsule")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.tertiary)
            Text("No modules enabled")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.text)
            Button {
                state.openSettings?()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 12)
    }

    private var batterySymbol: String {
        switch battery.percentage {
        case 88...: return "battery.100"
        case 63...: return "battery.75"
        case 38...: return "battery.50"
        case 13...: return "battery.25"
        default: return "battery.0"
        }
    }

    private func ensureValidTab() {
        guard !tabs.isEmpty else { return }
        if !tabs.contains(state.tab), let first = tabs.first {
            state.tab = first
        }
    }
}
