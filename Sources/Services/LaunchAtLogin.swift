import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService so settings and the menu bar item agree.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static var statusText: String {
        switch SMAppService.mainApp.status {
        case .enabled: return "On"
        case .requiresApproval: return "Waiting for approval"
        case .notFound: return "Not found"
        case .notRegistered: return "Off"
        @unknown default: return "Unknown"
        }
    }
}
