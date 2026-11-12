import SwiftUI

struct ConnectivityPane: View {
    @EnvironmentObject private var connectivity: ConnectivityService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                MicroLabel(text: "Connectivity")
                Spacer()
                Button {
                    connectivity.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.tertiary)
                        .frame(width: 14, height: 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.8))
                .help("Refresh")
            }

            wifiRow
            IslandDivider()
            bluetoothRow
            deviceList

            if let error = connectivity.lastError, !error.isEmpty {
                Text(error)
                    .font(.system(size: 8.5))
                    .foregroundStyle(Theme.offline)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 1)
    }

    private var wifiRow: some View {
        HStack(spacing: 8) {
            Image(systemName: connectivity.wifiPower ? "wifi" : "wifi.slash")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(connectivity.wifiPower ? Theme.text : Theme.tertiary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text("Wi-Fi")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(wifiDetail)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            IslandSwitch(
                isOn: Binding(
                    get: { connectivity.wifiPower },
                    set: { connectivity.setWiFi($0) }
                )
            )
        }
    }

    private var bluetoothRow: some View {
        HStack(spacing: 8) {
            BluetoothGlyph(
                color: connectivity.bluetoothPower ? Theme.text : Theme.tertiary
            )
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text("Bluetooth")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Text(bluetoothDetail)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            IslandSwitch(
                isOn: Binding(
                    get: { connectivity.bluetoothPower },
                    set: { connectivity.setBluetooth($0) }
                )
            )
        }
    }

    @ViewBuilder
    private var deviceList: some View {
        if connectivity.bluetoothPower, !connectivity.bluetoothDevices.isEmpty {
            let shown = Array(connectivity.bluetoothDevices.prefix(3))
            VStack(spacing: 3) {
                ForEach(shown) { device in
                    deviceRow(device)
                }
                if connectivity.bluetoothDevices.count > shown.count {
                    HStack {
                        Text("+\(connectivity.bluetoothDevices.count - shown.count) more paired")
                            .font(.system(size: 8.5))
                            .foregroundStyle(Theme.tertiary)
                        Spacer()
                    }
                }
            }
            .padding(.top, 1)
        }
    }

    private func deviceRow(_ device: ConnectivityService.BluetoothDevice) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(device.isConnected ? Theme.online : Theme.tertiary)
                .frame(width: 4, height: 4)

            Text(device.name)
                .font(.system(size: 9.5))
                .foregroundStyle(device.isConnected ? Theme.text : Theme.secondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Button(device.isConnected ? "Disconnect" : "Connect") {
                connectivity.toggleConnection(device)
            }
            .font(.system(size: 8.5, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Theme.fill))
            .buttonStyle(PressableButtonStyle(scale: 0.9))
        }
    }

    private var wifiDetail: String {
        guard connectivity.wifiPower else { return "Off" }
        guard connectivity.wifiConnected else { return "Not connected" }
        let name = connectivity.wifiSSID.isEmpty ? "" : "\(connectivity.wifiSSID) · "
        return "\(name)\(connectivity.wifiAddress) · \(connectivity.wifiRSSI) dBm"
    }

    private var bluetoothDetail: String {
        guard connectivity.bluetoothPower else { return "Off" }
        let connected = connectivity.bluetoothDevices.filter(\.isConnected).count
        return connected == 0 ? "On · no devices connected" : "On · \(connected) connected"
    }
}


/// The Bluetooth rune, drawn directly because SF Symbols has no Bluetooth mark.
private struct BluetoothGlyph: View {
    var color: Color

    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            var path = Path()

            path.move(to: CGPoint(x: width * 0.5, y: 0))
            path.addLine(to: CGPoint(x: width * 0.5, y: height))

            path.move(to: CGPoint(x: width * 0.5, y: 0))
            path.addLine(to: CGPoint(x: width, y: height * 0.26))
            path.addLine(to: CGPoint(x: 0, y: height * 0.74))

            path.move(to: CGPoint(x: width * 0.5, y: height))
            path.addLine(to: CGPoint(x: width, y: height * 0.74))
            path.addLine(to: CGPoint(x: 0, y: height * 0.26))

            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 11, height: 15)
    }
}
