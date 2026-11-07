import Combine

/// Placeholder for the server-status integration. The pane and the status enum
/// are ready; `check()` is the single place to wire in the user's endpoint,
/// command or API. Until then the tab explains what it will show.
@MainActor
final class ServerStatusService: ObservableObject {
    enum Status: Equatable {
        case notConfigured
        case checking
        case online(latencyMilliseconds: Int)
        case offline
    }

    @Published private(set) var status: Status = .notConfigured
    @Published var name: String = "My server"

    // TODO(server): Replace this body with the agreed integration. Keep the
    // `Status` cases so ServerPane keeps rendering uptime/latency consistently.
    func check() {
        status = .notConfigured
    }

    func previewSeed(status: Status) {
        self.status = status
    }
}
