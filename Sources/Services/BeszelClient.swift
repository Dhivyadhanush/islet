import Foundation

struct BeszelConfig: Equatable {
    var baseURL: String
    var email: String
    var password: String
    var accessClientID: String
    var accessClientSecret: String
}

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
    var updatedAt: Date

    var isOnline: Bool { status == "up" }
    var primaryInterface: String { interfaces.first ?? "" }
}

enum BeszelError: LocalizedError {
    case notConfigured
    case invalidURL
    case authFailed(String)
    case requestFailed(Int, String)
    case noSystems
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Server monitoring is not configured."
        case .invalidURL:
            return "The hub URL is not valid."
        case .authFailed(let message):
            return "Beszel login failed. \(message)"
        case .requestFailed(let code, let message):
            return "Beszel returned HTTP \(code). \(message)"
        case .noSystems:
            return "No systems are visible to this Beszel user."
        case .decoding(let message):
            return "Could not read the Beszel response. \(message)"
        }
    }
}

/// Minimal Beszel/PocketBase client for all systems visible to the account.
///
/// Auth:  POST /api/collections/users/auth-with-password
/// Data:  GET  /api/collections/systems/records
///        GET  /api/collections/system_stats/records
///
/// If Cloudflare Access protects the hub, the service token headers are added
/// to every request.
final class BeszelClient {
    private var token: String?
    private var tokenDate: Date?

    func fetch(config: BeszelConfig) async throws -> [BeszelMetrics] {
        guard !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.email.isEmpty,
              !config.password.isEmpty
        else { throw BeszelError.notConfigured }

        let base = try normalizedBase(config.baseURL)

        do {
            let token = try await authToken(base: base, config: config, force: false)
            return try await fetchOnce(base: base, config: config, token: token)
        } catch BeszelError.requestFailed(401, _) {
            let token = try await authToken(base: base, config: config, force: true)
            return try await fetchOnce(base: base, config: config, token: token)
        }
    }

    private func fetchOnce(base: URL, config: BeszelConfig, token: String) async throws -> [BeszelMetrics] {
        let systemsResponse = try await getJSON(
            base: base,
            path: "/api/collections/systems/records",
            query: [
                URLQueryItem(name: "perPage", value: "50"),
                URLQueryItem(name: "sort", value: "created"),
            ],
            token: token,
            config: config
        )

        guard let items = systemsResponse["items"] as? [[String: Any]],
              !items.isEmpty
        else { throw BeszelError.noSystems }

        var result: [BeszelMetrics] = []
        for system in items {
            result.append(await metrics(for: system, base: base, config: config, token: token))
        }
        return result
    }

    private func metrics(
        for system: [String: Any],
        base: URL,
        config: BeszelConfig,
        token: String
    ) async -> BeszelMetrics {
        let systemID = string(system["id"])
        let name = string(system["name"]).isEmpty ? "server" : string(system["name"])
        let status = string(system["status"])
        let host = string(system["host"])
        let info = dictionary(system["info"])

        var stats: [String: Any] = [:]
        if !systemID.isEmpty,
           let response = try? await getJSON(
               base: base,
               path: "/api/collections/system_stats/records",
               query: [
                   URLQueryItem(name: "perPage", value: "1"),
                   URLQueryItem(name: "sort", value: "-created"),
                   URLQueryItem(name: "filter", value: "(system='\(systemID)')"),
               ],
               token: token,
               config: config
           ),
           let records = response["items"] as? [[String: Any]],
           let latest = records.first {
            stats = dictionary(latest["stats"])
        }

        let memoryPercent = number(info["mp"])
        let diskPercent = number(info["dp"])

        var memoryUsed: UInt64?
        var memoryTotal: UInt64?
        if let mem = stats["mem"] as? [Any], mem.count >= 2 {
            memoryTotal = UInt64(max(number(mem[0]), 0))
            memoryUsed = UInt64(max(number(mem[1]), 0))
        }

        var diskUsed: Double?
        var diskTotal: Double?
        if stats["d"] != nil {
            diskTotal = number(stats["d"])
            diskUsed = number(stats["du"])
        }

        let interfaces = interfaceList(stats["ni"])
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
            memoryPercent: memoryPercent,
            memoryUsedBytes: memoryUsed,
            memoryTotalBytes: memoryTotal,
            diskPercent: diskPercent,
            diskUsedGB: diskUsed,
            diskTotalGB: diskTotal,
            networkSentBytesPerSecond: sent,
            networkReceivedBytesPerSecond: received,
            interfaces: interfaces,
            uptimeSeconds: number(info["u"]),
            cores: Int(number(info["c"])),
            threads: Int(number(info["t"])),
            model: string(info["m"]),
            os: string(info["o"]),
            updatedAt: Date()
        )
    }

    private func interfaceList(_ value: Any?) -> [String] {
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

    private func authToken(base: URL, config: BeszelConfig, force: Bool) async throws -> String {
        if !force, let token, let tokenDate, Date().timeIntervalSince(tokenDate) < 600 {
            return token
        }

        var request = URLRequest(url: base.appendingPathComponent("api/collections/users/auth-with-password"))
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAccessHeaders(to: &request, config: config)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "identity": config.email,
            "password": config.password,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BeszelError.authFailed("No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = errorMessage(data)
            throw BeszelError.authFailed(message.isEmpty ? "Check the email and password." : message)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String
        else { throw BeszelError.decoding("Missing auth token.") }

        self.token = token
        tokenDate = Date()
        return token
    }

    private func getJSON(
        base: URL,
        path: String,
        query: [URLQueryItem],
        token: String,
        config: BeszelConfig
    ) async throws -> [String: Any] {
        var components = URLComponents(
            url: base.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = query
        guard let url = components?.url else { throw BeszelError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(token, forHTTPHeaderField: "Authorization")
        addAccessHeaders(to: &request, config: config)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BeszelError.requestFailed(0, "No HTTP response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw BeszelError.requestFailed(http.statusCode, errorMessage(data))
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw BeszelError.decoding("Expected a JSON object.")
        }
        return json
    }

    private func addAccessHeaders(to request: inout URLRequest, config: BeszelConfig) {
        if !config.accessClientID.isEmpty {
            request.setValue(config.accessClientID, forHTTPHeaderField: "CF-Access-Client-Id")
        }
        if !config.accessClientSecret.isEmpty {
            request.setValue(config.accessClientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
    }

    private func normalizedBase(_ raw: String) throws -> URL {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.contains("://") { text = "https://\(text)" }
        while text.hasSuffix("/") { text.removeLast() }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { throw BeszelError.invalidURL }
        return url
    }

    private func errorMessage(_ data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return string(json["message"])
    }

    private func dictionary(_ value: Any?) -> [String: Any] {
        if let dictionary = value as? [String: Any] { return dictionary }
        if let text = value as? String,
           let data = text.data(using: .utf8),
           let dictionary = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dictionary
        }
        return [:]
    }

    private func string(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let text = value as? NSString { return text as String }
        return ""
    }

    private func number(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        if let text = value as? String { return Double(text) ?? 0 }
        return 0
    }
}
