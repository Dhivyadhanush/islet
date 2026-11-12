import SwiftUI

/// The expanded card. The tab strip lives in the menu-bar wings on both sides
/// of the notch; the focused pane hangs below the notch.
struct ExpandedView: View {
    @EnvironmentObject private var state: IslandState
    @EnvironmentObject private var battery: BatteryMonitor

    @AppStorage(Defaults.showMusic) private var showMusic = true
    @AppStorage(Defaults.showNetwork) private var showNetwork = true
    @AppStorage(Defaults.showScreenTime) private var showScreenTime = true
    @AppStorage(Defaults.showControls) private var showControls = true
    @AppStorage(Defaults.showCalendar) private var showCalendar = true
    @AppStorage(Defaults.showServer) private var showServer = true
    @AppStorage(Defaults.showBattery) private var showBattery = true

    @Namespace private var tabNamespace

    var body: some View {
        VStack(spacing: 0) {
            topRow
            pane
        }
        .onAppear { ensureValidTab() }
        .onChange(of: tabs) { _, _ in ensureValidTab() }
    }

    private var tabs: [IslandTab] {
        var result: [IslandTab] = []
        if showMusic { result.append(.music) }
        if showNetwork { result.append(.network) }
        if showScreenTime { result.append(.screenTime) }
        if showControls { result.append(.connectivity) }
        if showCalendar { result.append(.calendar) }
        if showServer { result.append(.server) }
        return result
    }

    private var splitIndex: Int { (tabs.count + 1) / 2 }
    private var leftTabs: [IslandTab] { Array(tabs.prefix(splitIndex)) }
    private var rightTabs: [IslandTab] { Array(tabs.dropFirst(splitIndex)) }

    private var topRowHeight: CGFloat {
        state.geometry.hasNotch ? state.geometry.notchHeight : 34
    }

    private var notchWidth: CGFloat {
        state.geometry.hasNotch ? state.geometry.notchWidth : 0
    }

    private var wingWidth: CGFloat {
        max((state.geometry.expandedSize.width - notchWidth) / 2, 0)
    }

    private var topRow: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                ForEach(leftTabs) { tab in
                    tabButton(tab)
                }
            }
            .padding(.trailing, 8)
            .frame(width: wingWidth, alignment: .trailing)

            if notchWidth > 0 {
                Color.clear.frame(width: notchWidth)
            }

            HStack(spacing: 3) {
                ForEach(rightTabs) { tab in
                    tabButton(tab)
                }

                Spacer(minLength: 3)

                if showBattery && battery.available {
                    batteryBadge
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
            .padding(.leading, 8)
            .padding(.trailing, 6)
            .frame(width: wingWidth, alignment: .leading)
        }
        .frame(height: topRowHeight)
    }

    private func tabButton(_ tab: IslandTab) -> some View {
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

    private var batteryBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: battery.charging ? "bolt.fill" : batterySymbol)
                .font(.system(size: 9, weight: .semibold))
            Text("\(battery.percentage)%")
                .monospacedDigit()
        }
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(battery.percentage <= 20 ? Theme.text : Theme.tertiary)
        .help(battery.charging ? "Charging" : "Battery")
    }

    @ViewBuilder
    private var pane: some View {
        if tabs.isEmpty {
            emptyState
        } else {
            Group {
                switch state.tab {
                case .music: MusicPane()
                case .network: NetworkPane()
                case .screenTime: ScreenTimePane()
                case .connectivity: ConnectivityPane()
                case .calendar: CalendarPane()
                case .server: ServerPane()
                }
            }
            .id(state.tab)
            .transition(.opacity)
            .animation(Theme.fade, value: state.tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 16)
            .padding(.top, 8)
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
        .padding(.top, 8)
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
