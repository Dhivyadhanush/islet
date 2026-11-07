import Foundation

/// Every preference key lives here so the settings window, the island and the
/// controller cannot drift apart.
enum Defaults {
    static let showMusic = "islet.showMusic"
    static let showNetwork = "islet.showNetwork"
    static let showScreenTime = "islet.showScreenTime"
    static let showControls = "islet.showControls"
    static let showCalendar = "islet.showCalendar"
    static let showServer = "islet.showServer"
    static let hoverExpand = "islet.hoverExpand"
    static let calmMotion = "islet.calmMotion"
    static let showBattery = "islet.showBattery"
    static let serverCPU = "islet.server.cpu"
    static let serverRAM = "islet.server.ram"
    static let serverDisk = "islet.server.disk"
    static let serverNetwork = "islet.server.network"

    static let registered: [String: Any] = [
        showMusic: true,
        showNetwork: true,
        showScreenTime: true,
        showControls: true,
        showCalendar: true,
        showServer: true,
        hoverExpand: true,
        calmMotion: false,
        showBattery: true,
        serverCPU: true,
        serverRAM: true,
        serverDisk: true,
        serverNetwork: true,
    ]

    static func register() {
        UserDefaults.standard.register(defaults: registered)
    }
}

enum ByteFormat {
    private static func formatter(_ units: ByteCountFormatter.Units) -> ByteCountFormatter {
        let f = ByteCountFormatter()
        f.allowedUnits = units
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        f.isAdaptive = true
        return f
    }

    static func bytes(_ value: UInt64) -> String {
        if value == 0 { return "0 KB" }
        return formatter([.useKB, .useMB, .useGB]).string(fromByteCount: Int64(value))
    }

    static func rate(_ value: Double) -> String {
        guard value >= 1 else { return "0 KB/s" }
        let text = formatter([.useKB, .useMB, .useGB]).string(fromByteCount: Int64(value))
        return text + "/s"
    }
}

enum ScreenTimeFormat {
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    static func compact(_ seconds: TimeInterval) -> String {
        let total = max(Int(seconds.rounded()), 0)
        if total <= 0 { return "0m" }
        if total >= 3600 {
            return String(format: "%dh %02dm", total / 3600, (total % 3600) / 60)
        }
        return "\(max(1, total / 60))m"
    }
}

enum TimeText {
    static let clock: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("j:mm")
        return f
    }()

    static let weekdayDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEE d MMM")
        return f
    }()

    static let dayLetter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.setLocalizedDateFormatFromTemplate("EEEEE")
        return f
    }()

    static func short(_ date: Date) -> String {
        clock.string(from: date)
    }

    static func relative(to date: Date) -> String {
        let seconds = date.timeIntervalSinceNow
        if seconds <= 60 { return "now" }
        let minutes = Int((seconds / 60).rounded(.up))
        if minutes < 60 { return "in \(minutes)m" }
        return clock.string(from: date)
    }
}
