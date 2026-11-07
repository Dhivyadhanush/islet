import Combine
import Foundation

/// Beszel server status and metrics for the Server tab.
///
/// Configuration is entered in Settings → Server. The hub URL, email and
/// Cloudflare Access client ID are stored in UserDefaults; the Beszel password
/// and Access client secret are stored in a 0600 local credentials file so they
/// survive rebuilds of this ad-hoc-signed app.
@MainActor
final class ServerStatusService: ObservableObject {
    enum Status: Equatable {
        case notConfigured
        case checking
        case online
        case offline
        case error(String)
    }

    struct PublicConfig {
        var baseURL: String
        var email: String
        var accessClientID: String
        var hasPassword: Bool
        var hasAccessSecret: Bool
    }

    @Published private(set) var status: Status = .notConfigured
    @Published private(set) var systems: [BeszelMetrics] = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    private let client = BeszelClient()
    private var timer: Timer?

    private enum Keys {
        static let url = "islet.beszel.url"
        static let email = "islet.beszel.email"
        static let accessID = "islet.beszel.accessID"
    }

    var publicConfig: PublicConfig {
        let defaults = UserDefaults.standard
        return PublicConfig(
            baseURL: defaults.string(forKey: Keys.url) ?? "",
            email: defaults.string(forKey: Keys.email) ?? "",
            accessClientID: defaults.string(forKey: Keys.accessID) ?? "",
            hasPassword: !(CredentialStore.load()?.password ?? "").isEmpty,
            hasAccessSecret: !(CredentialStore.load()?.accessSecret ?? "").isEmpty
        )
    }

    var isConfigured: Bool {
        let config = publicConfig
        return !config.baseURL.isEmpty && !config.email.isEmpty && config.hasPassword
    }

    var onlineCount: Int {
        systems.filter(\.isOnline).count
    }

    func start() {
        guard timer == nil else { return }
        if isConfigured { refresh() }

        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func check() {
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        guard let config = currentConfig() else {
            status = .notConfigured
            systems = []
            return
        }

        isRefreshing = true
        if systems.isEmpty { status = .checking }

        Task {
            do {
                let fetched = try await client.fetch(config: config)
                systems = fetched
                lastError = nil
                lastUpdated = Date()
                status = fetched.contains(where: \.isOnline) ? .online : .offline
            } catch {
                lastError = error.localizedDescription
                status = .error(error.localizedDescription)
            }
            isRefreshing = false
        }
    }

    func save(
        baseURL: String,
        email: String,
        password: String,
        accessClientID: String,
        accessClientSecret: String
    ) {
        Self.saveConfig(
            baseURL: baseURL,
            email: email,
            password: password,
            accessClientID: accessClientID,
            accessClientSecret: accessClientSecret
        )
        systems = []
        lastError = nil
        refresh()
    }

    /// Writes the configuration without touching the network. Used by the
    /// Settings window and by the headless `--beszel-save` helper.
    static func saveConfig(
        baseURL: String,
        email: String,
        password: String,
        accessClientID: String,
        accessClientSecret: String
    ) {
        let defaults = UserDefaults.standard
        defaults.set(baseURL.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.url)
        defaults.set(email.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.email)
        defaults.set(accessClientID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.accessID)

        CredentialStore.save(
            password: password.isEmpty ? nil : password,
            accessSecret: accessClientSecret.isEmpty ? nil : accessClientSecret
        )
    }

    func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.url)
        defaults.removeObject(forKey: Keys.email)
        defaults.removeObject(forKey: Keys.accessID)
        CredentialStore.clear()
        systems = []
        lastError = nil
        lastUpdated = nil
        status = .notConfigured
    }

    /// Used by `--snapshot` to render the online dashboard.
    func previewSeed(systems: [BeszelMetrics]) {
        self.systems = systems
        lastUpdated = systems.first?.updatedAt ?? Date()
        status = systems.contains(where: \.isOnline) ? .online : .offline
    }

    private func currentConfig() -> BeszelConfig? {
        let publicConfig = publicConfig
        guard !publicConfig.baseURL.isEmpty,
              !publicConfig.email.isEmpty,
              let password = CredentialStore.load()?.password,
              !password.isEmpty
        else { return nil }

        return BeszelConfig(
            baseURL: publicConfig.baseURL,
            email: publicConfig.email,
            password: password,
            accessClientID: publicConfig.accessClientID,
            accessClientSecret: CredentialStore.load()?.accessSecret ?? ""
        )
    }
}
