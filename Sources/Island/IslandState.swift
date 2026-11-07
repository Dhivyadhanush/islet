import SwiftUI
import AppKit

enum IslandTab: String, CaseIterable, Identifiable {
    case music
    case screenTime
    case controls
    case calendar
    case server

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: return "Music"
        case .screenTime: return "Screen Time"
        case .controls: return "Controls"
        case .calendar: return "Calendar"
        case .server: return "Server"
        }
    }

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .screenTime: return "hourglass"
        case .controls: return "slider.horizontal.3"
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
