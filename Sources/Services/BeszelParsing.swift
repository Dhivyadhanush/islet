import Foundation

struct BeszelMetrics: Equatable {
    var id: String
    var name: String
    var hostname: String
    var host: String
    var status: String
    var cpuPercent: Double
    var memoryPercent: Double
    var memoryUsedBytes: UInt64?
    var memoryTotalBytes: UInt64?
    var diskPercent: Double
    var diskUsedGB: Double?
    var diskTotalGB: Double?
    var networkSentBytesPerSecond: Double
    var networkReceivedBytesPerSecond: Double
    var interfaces: [String]
    var uptimeSeconds: Double
    var cores: Int
    var threads: Int
    var model: String
    var os: String
    /// Timestamp of the Beszel sample, not the time it was fetched. An offline
    /// system then shows how old its data is instead of looking fresh.
    var updatedAt: Date

    var isOnline: Bool { status == "up" }
    var primaryInterface: String { interfaces.first ?? "" }
}

/// Pure parsing for Beszel/PocketBase dictionaries. Kept separate from the
/// network client so the mapping can be tested without a hub or URLSession.
enum BeszelParsing {
    static func metrics(
        system: [String: Any],
        statsRecord: [String: Any]?,
        now: Date = Date()
    ) -> BeszelMetrics {
        let systemID = string(system["id"])
        let name = string(system["name"]).isEmpty ? "server" : string(system["name"])
        let status = string(system["status"])
        let host = string(system["host"])
        let info = dictionary(system["info"])
        let stats = dictionary(statsRecord?["stats"])

        var memoryUsed: UInt64?
        var memoryTotal: UInt64?
        if let memory = stats["mem"] as? [Any], memory.count >= 2 {
            memoryTotal = UInt64(max(number(memory[0]), 0))
            memoryUsed = UInt64(max(number(memory[1]), 0))
        }

        var diskUsed: Double?
        var diskTotal: Double?
        if stats["d"] != nil {
            diskTotal = number(stats["d"])
            diskUsed = number(stats["du"])
        }

        let bandwidth = stats["b"] as? [Any] ?? []
        let sent = bandwidth.count >= 2 ? number(bandwidth[0]) : 0
        let received = bandwidth.count >= 2 ? number(bandwidth[1]) : 0

        return BeszelMetrics(
            id: systemID,
            name: name,
            hostname: string(info["h"]),
            host: host,
            status: status,
            cpuPercent: number(info["cpu"]),
            memoryPercent: number(info["mp"]),
            memoryUsedBytes: memoryUsed,
            memoryTotalBytes: memoryTotal,
            diskPercent: number(info["dp"]),
            diskUsedGB: diskUsed,
            diskTotalGB: diskTotal,
            networkSentBytesPerSecond: sent,
            networkReceivedBytesPerSecond: received,
            interfaces: interfaceList(stats["ni"]),
            uptimeSeconds: number(info["u"]),
            cores: Int(number(info["c"])),
            threads: Int(number(info["t"])),
            model: string(info["m"]),
            os: string(info["o"]),
            updatedAt: date(statsRecord?["created"]) ?? now
        )
    }

    /// Puts the busiest current interface first, falling back to the interface
    /// with the largest lifetime counters when the current rate is zero.
    static func interfaceList(_ value: Any?) -> [String] {
        guard let dictionary = value as? [String: Any] else { return [] }
        var bestName = ""
        var bestCurrent = -1.0
        var bestTotalName = ""
        var bestTotal = -1.0
        var names: [String] = []

        for (name, raw) in dictionary {
            guard name != "lo" else { continue }
            names.append(name)
            if let counters = raw as? [Any], counters.count >= 4 {
                let current = number(counters[0]) + number(counters[1])
                let total = number(counters[2]) + number(counters[3])
                if current > bestCurrent {
                    bestCurrent = current
                    bestName = name
                }
                if total > bestTotal {
                    bestTotal = total
                    bestTotalName = name
                }
            }
        }

        if bestCurrent <= 0 { bestName = bestTotalName }
        names.sort()
        if let index = names.firstIndex(of: bestName) {
            names.remove(at: index)
            names.insert(bestName, at: 0)
        }
        return names
    }

    /// PocketBase returns `created` as `yyyy-MM-dd HH:mm:ss.SSSZ`, while other
    /// hubs use ISO-8601. Accept both.
    static func date(_ value: Any?) -> Date? {
        if let date = value as? Date { return date }
        guard let text = value as? String, !text.isEmpty else { return nil }

        if let date = isoFractional.date(from: text) { return date }
        if let date = iso.date(from: text) { return date }
        if let date = pocketBaseMillis.date(from: text) { return date }
        return pocketBase.date(from: text)
    }

    static func dictionary(_ value: Any?) -> [String: Any] {
        if let dictionary = value as? [String: Any] { return dictionary }
        if let text = value as? String,
           let data = text.data(using: .utf8),
           let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dictionary
        }
        return [:]
    }

    static func string(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let text = value as? NSString { return text as String }
        return ""
    }

    static func number(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let text = value as? String { return Double(text) ?? 0 }
        return 0
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let pocketBaseMillis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS'Z'"
        return formatter
    }()

    private static let pocketBase: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss'Z'"
        return formatter
    }()
}
