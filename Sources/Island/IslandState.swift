import SwiftUI
import AppKit

enum IslandTab: String, CaseIterable, Identifiable {
    case music
    case network
    case screenTime
    case connectivity
    case calendar
    case server

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: return "Music"
        case .network: return "Network"
        case .screenTime: return "Screen Time"
        case .connectivity: return "Connectivity"
        case .calendar: return "Calendar"
        case .server: return "Server"
        }
    }

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .network: return "arrow.up.arrow.down"
        case .screenTime: return "hourglass"
        case .connectivity: return "wifi"
        case .calendar: return "calendar"
        case .server: return "server.rack"
        }
    }
}

/// Shared, observable island state. The controller owns the window; SwiftUI
/// only reads this object and calls back through the closures.
@MainActor
final class IslandState: ObservableObject {
    @Published var expanded = false
    @Published var pinned = false
    @Published var hovered = false
    @Published var tab: IslandTab = .music
    @Published var geometry = IslandGeometry()

    var onHover: ((Bool) -> Void)?
    var onExpandNow: (() -> Void)?
    var onTogglePin: (() -> Void)?
    var openSettings: (() -> Void)?
}
