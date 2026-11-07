import Combine
import Foundation

/// Beszel server status and metrics for the Server tab.
///
/// Configuration is entered in Settings → Server. The hub URL, email and
/// Cloudflare Access client ID are stored in UserDefaults; the Beszel password
/// and Access client secret are stored in Keychain.
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
    @Published private(set) var metrics: BeszelMetrics?
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false

    private let client = BeszelClient()
    private var timer: Timer?

    private enum Keys {
        static let url = "islet.beszel.url"
        static let email = "islet.beszel.email"
        static let accessID = "islet.beszel.accessID"
        static let passwordAccount = "beszel.password"
        static let accessSecretAccount = "beszel.accessSecret"
    }

    var publicConfig: PublicConfig {
        let defaults = UserDefaults.standard
        return PublicConfig(
            baseURL: defaults.string(forKey: Keys.url) ?? "",
            email: defaults.string(forKey: Keys.email) ?? "",
            accessClientID: defaults.string(forKey: Keys.accessID) ?? "",
            hasPassword: !(Keychain.get(account: Keys.passwordAccount) ?? "").isEmpty,
            hasAccessSecret: !(Keychain.get(account: Keys.accessSecretAccount) ?? "").isEmpty
        )
    }

    var isConfigured: Bool {
        let config = publicConfig
        return !config.baseURL.isEmpty && !config.email.isEmpty && config.hasPassword
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
            metrics = nil
            return
        }

        isRefreshing = true
        if metrics == nil { status = .checking }

        Task {
            do {
                let fetched = try await client.fetch(config: config)
                metrics = fetched
                lastError = nil
                lastUpdated = Date()
                status = fetched.isOnline ? .online : .offline
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
        metrics = nil
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

        if !password.isEmpty {
            Keychain.set(password, account: Keys.passwordAccount)
        }
        if !accessClientSecret.isEmpty {
            Keychain.set(accessClientSecret, account: Keys.accessSecretAccount)
        }
    }

    func clear() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Keys.url)
        defaults.removeObject(forKey: Keys.email)
        defaults.removeObject(forKey: Keys.accessID)
        Keychain.delete(account: Keys.passwordAccount)
        Keychain.delete(account: Keys.accessSecretAccount)
        metrics = nil
        lastError = nil
        lastUpdated = nil
        status = .notConfigured
    }

    /// Used by `--snapshot` to render the online dashboard.
    func previewSeed(metrics: BeszelMetrics) {
        self.metrics = metrics
        lastUpdated = metrics.updatedAt
        status = metrics.isOnline ? .online : .offline
    }

    private func currentConfig() -> BeszelConfig? {
        let publicConfig = publicConfig
        guard !publicConfig.baseURL.isEmpty,
              !publicConfig.email.isEmpty,
              let password = Keychain.get(account: Keys.passwordAccount),
              !password.isEmpty
        else { return nil }

        return BeszelConfig(
            baseURL: publicConfig.baseURL,
            email: publicConfig.email,
            password: password,
            accessClientID: publicConfig.accessClientID,
            accessClientSecret: Keychain.get(account: Keys.accessSecretAccount) ?? ""
        )
    }
}
