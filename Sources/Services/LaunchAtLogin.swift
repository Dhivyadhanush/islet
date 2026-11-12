import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService so settings and the menu bar item agree.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// True once macOS has the item, even if the user still has to approve it.
    static var isRegistered: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            guard !isRegistered else { return }
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
