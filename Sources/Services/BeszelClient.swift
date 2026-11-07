import Foundation

struct BeszelConfig: Equatable {
    var baseURL: String
    var email: String
    var password: String
    var accessClientID: String
    var accessClientSecret: String
}

struct BeszelMetrics: Equatable {
    var name: String
    var hostname: String
    var status: String
    var cpuPercent: Double
    var memoryPercent: Double
    var memoryUsedBytes: UInt64?
    var memoryTotalBytes: UInt64?
    var diskPercent: Double
    var diskUsedGB: Double?
    var diskTotalGB: Double?
    var uptimeSeconds: Double
    var cores: Int
    var threads: Int
    var model: String
    var os: String
    var updatedAt: Date

    var isOnline: Bool { status == "up" }
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

/// Minimal Beszel/PocketBase client.
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

    func fetch(config: BeszelConfig) async throws -> BeszelMetrics {
        guard !config.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !config.email.isEmpty,
              !config.password.isEmpty
        else { throw BeszelError.notConfigured }

        let base = try normalizedBase(config.baseURL)

        do {
            return try await fetchOnce(base: base, config: config, token: try await authToken(base: base, config: config, force: false))
        } catch BeszelError.requestFailed(401, _) {
            return try await fetchOnce(base: base, config: config, token: try await authToken(base: base, config: config, force: true))
        }
    }

    private func fetchOnce(base: URL, config: BeszelConfig, token: String) async throws -> BeszelMetrics {
        let systemsResponse = try await getJSON(
            base: base,
            path: "/api/collections/systems/records",
            query: [
                URLQueryItem(name: "perPage", value: "50"),
                URLQueryItem(name: "sort", value: "name"),
            ],
            token: token,
            config: config
        )

        guard let items = systemsResponse["items"] as? [[String: Any]],
              let system = items.first
        else { throw BeszelError.noSystems }

        let systemID = system["id"] as? String ?? ""
        let name = system["name"] as? String ?? "server"
        let status = system["status"] as? String ?? "unknown"
        let info = dictionary(system["info"])

        var stats: [String: Any] = [:]
        if !systemID.isEmpty {
            // The read-only role may not be allowed to list every collection.
            // The system info still carries the percentages, so this is optional.
            if let response = try? await getJSON(
                base: base,
                path: "/api/collections/system_stats/records",
                query: [
                    URLQueryItem(name: "perPage", value: "1"),
                    URLQueryItem(name: "sort", value: "-created"),
                    URLQueryItem(name: "filter", value: "(system='\(systemID)')"),
                ],
                token: token,
                config: config
            ), let records = response["items"] as? [[String: Any]],
               let latest = records.first {
                stats = dictionary(latest["stats"])
            }
        }

        let cpu = number(info["cpu"])
        let memoryPercent = number(info["mp"])
        let diskPercent = number(info["dp"])
        let uptime = number(info["u"])
        let cores = Int(number(info["c"]))
        let threads = Int(number(info["t"]))
        let model = string(info["m"])
        let hostname = string(info["h"])
        let os = string(info["o"])

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

        return BeszelMetrics(
            name: name,
            hostname: hostname,
            status: status,
            cpuPercent: cpu,
            memoryPercent: memoryPercent,
            memoryUsedBytes: memoryUsed,
            memoryTotalBytes: memoryTotal,
            diskPercent: diskPercent,
            diskUsedGB: diskUsed,
            diskTotalGB: diskTotal,
            uptimeSeconds: uptime,
            cores: cores,
            threads: threads,
            model: model,
            os: os,
            updatedAt: Date()
        )
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
