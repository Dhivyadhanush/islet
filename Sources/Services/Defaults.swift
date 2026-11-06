import Foundation

/// Every preference key lives here so the settings window, the island and the
/// controller cannot drift apart.
enum Defaults {
    static let showMusic = "islet.showMusic"
    static let showNetwork = "islet.showNetwork"
    static let showControls = "islet.showControls"
    static let showCalendar = "islet.showCalendar"
    static let compactSource = "islet.compactSource"
    static let hoverExpand = "islet.hoverExpand"
    static let calmMotion = "islet.calmMotion"
    static let showBattery = "islet.showBattery"
    static let showSource = "islet.showSource"

    static let registered: [String: Any] = [
        showMusic: true,
        showNetwork: true,
        showControls: true,
        showCalendar: true,
        compactSource: "auto",
        hoverExpand: true,
        calmMotion: false,
        showBattery: true,
        showSource: true,
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
