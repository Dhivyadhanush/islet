import Foundation
import IOKit.ps
import Combine

/// Battery level and charging state for the header. Uses the public IOKit
/// power-source API, so no permissions are involved.
@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var percentage: Int = 0
    @Published private(set) var charging = false
    @Published private(set) var available = false

    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        read()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.read() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func previewSeed(percentage: Int, charging: Bool, available: Bool = true) {
        self.percentage = percentage
        self.charging = charging
        self.available = available
    }

    private func read() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            available = false
            return
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard let type = description["Type"] as? String, type == "InternalBattery" else { continue }

            let current = description["Current Capacity"] as? Int ?? 0
            let maximum = description["Max Capacity"] as? Int ?? 100
            percentage = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0
            charging = description["Is Charging"] as? Bool ?? false
            available = true
            return
        }
        available = false
    }
}
