import CoreWLAN
import Foundation
import IOBluetooth
import SwiftUI

@_silgen_name("IOBluetoothPreferenceGetControllerPowerState")
private func bluetoothPowerState() -> Int32

@_silgen_name("IOBluetoothPreferenceSetControllerPowerState")
private func setBluetoothPowerState(_ state: Int32)

/// Wi-Fi and Bluetooth state for the Connectivity tab.
@MainActor
final class ConnectivityService: ObservableObject {
    struct BluetoothDevice: Identifiable, Equatable {
        let id: String
        let name: String
        let isConnected: Bool
    }

    @Published private(set) var wifiPower = false
    @Published private(set) var wifiConnected = false
    @Published private(set) var wifiSSID = ""
    @Published private(set) var wifiAddress = ""
    @Published private(set) var wifiRSSI = 0
    @Published private(set) var bluetoothPower = false
    @Published private(set) var bluetoothDevices: [BluetoothDevice] = []
    @Published private(set) var lastError: String?

    private let wifiClient = CWWiFiClient.shared()
    private var timer: Timer?

    func start() {
        guard timer == nil else { return }
        refresh()
        let tick = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        if let interface = wifiClient.interface() {
            wifiPower = interface.powerOn()
            wifiSSID = interface.ssid() ?? ""
            wifiRSSI = interface.rssiValue()
            wifiAddress = Self.ipv4Address(interface: interface.interfaceName ?? "")
            wifiConnected = !wifiAddress.isEmpty
        } else {
            wifiPower = false
            wifiConnected = false
            wifiSSID = ""
            wifiAddress = ""
            wifiRSSI = 0
        }

        bluetoothPower = bluetoothPowerState() != 0
        if bluetoothPower {
            let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
            bluetoothDevices = paired.compactMap { device in
                guard let address = device.addressString else { return nil }
                return BluetoothDevice(
                    id: address,
                    name: device.name ?? address,
                    isConnected: device.isConnected()
                )
            }
            .sorted { left, right in
                if left.isConnected != right.isConnected { return left.isConnected }
                return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
        } else {
            bluetoothDevices = []
        }
    }

    func setWiFi(_ enabled: Bool) {
        guard let interface = wifiClient.interface() else {
            lastError = "No Wi-Fi interface"
            return
        }
        do {
            try interface.setPower(enabled)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func setBluetooth(_ enabled: Bool) {
        setBluetoothPowerState(enabled ? 1 : 0)
        lastError = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.refresh()
        }
    }

    func toggleConnection(_ device: BluetoothDevice) {
        guard let paired = IOBluetoothDevice(addressString: device.id) else { return }
        if paired.isConnected() {
            paired.closeConnection()
        } else {
            paired.openConnection()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.refresh()
        }
    }

    /// Used by `--snapshot` so the preview is deterministic.
    func previewSeed(
        wifiPower: Bool,
        wifiConnected: Bool,
        wifiAddress: String,
        wifiRSSI: Int,
        bluetoothPower: Bool,
        devices: [BluetoothDevice]
    ) {
        self.wifiPower = wifiPower
        self.wifiConnected = wifiConnected
        self.wifiAddress = wifiAddress
        self.wifiRSSI = wifiRSSI
        self.bluetoothPower = bluetoothPower
        self.bluetoothDevices = devices
    }

    private static func ipv4Address(interface: String) -> String {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return "" }
        defer { freeifaddrs(head) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let entry = current.pointee
            if let address = entry.ifa_addr,
               address.pointee.sa_family == UInt8(AF_INET),
               String(cString: entry.ifa_name) == interface {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let result = getnameinfo(
                    address,
                    socklen_t(address.pointee.sa_len),
                    &host,
                    socklen_t(host.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
                if result == 0 {
                    return String(cString: host)
                }
            }
            pointer = entry.ifa_next
        }
        return ""
    }
}
