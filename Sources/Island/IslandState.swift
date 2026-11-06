import SwiftUI
import AppKit

enum IslandTab: String, CaseIterable, Identifiable {
    case music
    case network
    case controls
    case calendar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .music: return "Music"
        case .network: return "Network"
        case .controls: return "Controls"
        case .calendar: return "Calendar"
        }
    }

    var icon: String {
        switch self {
        case .music: return "music.note"
        case .network: return "arrow.up.arrow.down"
        case .controls: return "slider.horizontal.3"
        case .calendar: return "calendar"
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
