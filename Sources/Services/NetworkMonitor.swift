import Foundation
import Darwin

/// Daily network totals from the kernel's interface counters.
///
/// Counters are 32-bit on macOS, so we accumulate deltas instead of trusting
/// absolute values. A counter that goes backwards is treated as an interface
/// reset (and ignored for that tick), which is safe at a 2s sampling rate.
@MainActor
final class NetworkMonitor: ObservableObject {
    struct DayUsage: Identifiable, Equatable {
        let key: String
        let date: Date
        let down: UInt64
        let up: UInt64
        var total: UInt64 { down &+ up }
        var id: String { key }
    }

    @Published private(set) var todayDown: UInt64 = 0
    @Published private(set) var todayUp: UInt64 = 0
    @Published private(set) var rate: Double = 0
    @Published private(set) var history: [DayUsage] = []

    var todayTotal: UInt64 { todayDown &+ todayUp }

    private struct Archive: Codable {
        var day: String
        var down: UInt64
        var up: UInt64
        var history: [String: [UInt64]]
    }

    private let storeKey = "islet.network.archive.v1"
    private var archive: [String: [UInt64]] = [:]
    private var currentDay = ""
    private var lastCounters: [String: (rx: UInt64, tx: UInt64)] = [:]
    private var lastSample: Date?
    private var lastPersist = Date.distantPast
    private var timer: Timer?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func start() {
        guard timer == nil else { return }
        load()
        currentDay = Self.key(for: Date())
        prune()
        sample(isInitial: true)
        rebuildHistory()

        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample(isInitial: false) }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func flush() {
        persist()
    }

    func reset() {
        todayDown = 0
        todayUp = 0
        rate = 0
        archive.removeAll()
        currentDay = Self.key(for: Date())
        // Re-baseline the kernel counters so the reset does not immediately
        // re-add traffic from the last sampling window.
        lastCounters = Self.readCounters()
        lastSample = Date()
        persist()
        rebuildHistory()
    }

    /// Used by `--snapshot` to render the design with sample numbers.
    func previewSeed(down: UInt64, up: UInt64, rate: Double, history: [DayUsage]) {
        todayDown = down
        todayUp = up
        self.rate = rate
        self.history = history
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let decoded = try? JSONDecoder().decode(Archive.self, from: data) else { return }
        archive = decoded.history
        if decoded.day == Self.key(for: Date()) {
            todayDown = decoded.down
            todayUp = decoded.up
        }
    }

    private func persist() {
        var merged = archive
        merged[currentDay] = [todayDown, todayUp]
        let payload = Archive(day: currentDay, down: todayDown, up: todayUp, history: merged)
        if let data = try? JSONEncoder().encode(payload) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func sample(isInitial: Bool) {
        rolloverIfNeeded()
        let counters = Self.readCounters()
        defer { lastCounters = counters }

        guard !isInitial, let previousDate = lastSample else {
            lastSample = Date()
            return
        }

        let elapsed = max(Date().timeIntervalSince(previousDate), 0.2)
        var downDelta: UInt64 = 0
        var upDelta: UInt64 = 0
        for (name, counter) in counters {
            guard let old = lastCounters[name] else { continue }
            if counter.rx >= old.rx { downDelta &+= counter.rx - old.rx }
            if counter.tx >= old.tx { upDelta &+= counter.tx - old.tx }
        }

        todayDown &+= downDelta
        todayUp &+= upDelta

        let instant = Double(downDelta &+ upDelta) / elapsed
        rate = rate == 0 ? instant : (rate * 0.55 + instant * 0.45)

        lastSample = Date()
        rebuildHistory()

        if Date().timeIntervalSince(lastPersist) > 10 {
            persist()
            lastPersist = Date()
        }
    }

    private func rolloverIfNeeded() {
        let key = Self.key(for: Date())
        guard key != currentDay, !currentDay.isEmpty else { return }
        archive[currentDay] = [todayDown, todayUp]
        currentDay = key
        todayDown = 0
        todayUp = 0
        rate = 0
        prune()
        rebuildHistory()
        persist()
    }

    private func prune() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -20, to: Date()) ?? Date()
        archive = archive.filter { entry in
            guard let date = Self.date(fromKey: entry.key) else { return false }
            return date >= cutoff
        }
    }

    private func rebuildHistory() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var items: [DayUsage] = []
        for offset in stride(from: 6, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = Self.key(for: date)
            let pair = key == currentDay ? [todayDown, todayUp] : (archive[key] ?? [0, 0])
            items.append(DayUsage(key: key, date: date, down: pair[0], up: pair[1]))
        }
        history = items
    }

    private static func readCounters() -> [String: (rx: UInt64, tx: UInt64)] {
        var result: [String: (rx: UInt64, tx: UInt64)] = [:]
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return result }
        defer { freeifaddrs(pointer) }

        var current = first
        while true {
            let interface = current.pointee
            let name = String(cString: interface.ifa_name)
            if isPhysical(name),
               let address = interface.ifa_addr,
               address.pointee.sa_family == UInt8(AF_LINK),
               let data = interface.ifa_data {
                let counters = data.assumingMemoryBound(to: if_data.self).pointee
                result[name] = (UInt64(counters.ifi_ibytes), UInt64(counters.ifi_obytes))
            }
            guard let next = interface.ifa_next else { break }
            current = next
        }
        return result
    }

    /// Wi-Fi, Ethernet, Thunderbolt and iPhone tethering all live under "en".
    /// VPN tunnels are excluded so the same bytes are not counted twice.
    private static func isPhysical(_ name: String) -> Bool {
        name.hasPrefix("en") || name.hasPrefix("pdp_ip")
    }

    private static func key(for date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static func date(fromKey key: String) -> Date? {
        dayFormatter.date(from: key)
    }
}
