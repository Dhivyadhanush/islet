import SwiftUI
import CoreAudio
import AudioToolbox
import CoreGraphics
import Darwin

/// Volume via CoreAudio and brightness via DisplayServices. Both are cheap
/// enough to apply live while dragging a slider.
@MainActor
final class SystemControls: ObservableObject {
    @Published private(set) var volume: Double = 0.5
    @Published private(set) var muted = false
    @Published private(set) var brightness: Double = 0.5
    @Published private(set) var brightnessAvailable = true

    private var timer: Timer?
    private var volumeEditing = false
    private var brightnessEditing = false

    func start() {
        guard timer == nil else { return }
        readAll()
        let t = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.readAll() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func setVolume(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        volume = clamped
        if muted {
            muted = false
            Self.writeMuted(false)
        }
        Self.writeVolume(Float(clamped))
    }

    func setBrightness(_ value: Double) {
        let clamped = min(max(value, 0), 1)
        brightness = clamped
        if !Self.writeBrightness(Float(clamped)) {
            brightnessAvailable = false
        }
    }

    func toggleMute() {
        muted.toggle()
        Self.writeMuted(muted)
    }

    /// Used by `--snapshot` to render the design with sample values.
    func previewSeed(volume: Double, brightness: Double, muted: Bool = false) {
        self.volume = volume
        self.brightness = brightness
        self.muted = muted
    }

    func setVolumeEditing(_ editing: Bool) {
        volumeEditing = editing
        if !editing { readVolume() }
    }

    func setBrightnessEditing(_ editing: Bool) {
        brightnessEditing = editing
        if !editing { readBrightness() }
    }

    private func readAll() {
        if !volumeEditing { readVolume() }
        if !brightnessEditing { readBrightness() }
    }

    private func readVolume() {
        if let value = Self.readVolume() { volume = Double(value) }
        muted = Self.readMuted()
    }

    private func readBrightness() {
        if let value = Self.readBrightness() {
            brightness = Double(value)
            brightnessAvailable = true
        }
    }

    // MARK: - CoreAudio

    private static func defaultOutputDevice() -> AudioDeviceID {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &size, &device
        )
        return device
    }

    private static func readVolume() -> Float? {
        let device = defaultOutputDevice()
        guard device != 0 else { return nil }

        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: element
            )
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr {
                return value
            }
        }

        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: element
            )
            var value: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr {
                return value
            }
        }
        return nil
    }

    private static func writeVolume(_ value: Float) {
        let device = defaultOutputDevice()
        guard device != 0 else { return }
        var mutable = value
        let size = UInt32(MemoryLayout<Float32>.size)

        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: element
            )
            if AudioObjectSetPropertyData(device, &address, 0, nil, size, &mutable) == noErr {
                return
            }
        }

        for element in [kAudioObjectPropertyElementMain, 1, 2] {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioObjectPropertyScopeOutput,
                mElement: element
            )
            if AudioObjectSetPropertyData(device, &address, 0, nil, size, &mutable) == noErr {
                return
            }
        }
    }

    private static func readMuted() -> Bool {
        let device = defaultOutputDevice()
        guard device != 0 else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else {
            return false
        }
        return value != 0
    }

    private static func writeMuted(_ muted: Bool) {
        let device = defaultOutputDevice()
        guard device != 0 else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(
            device, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &value
        )
    }

    // MARK: - DisplayServices

    private static func readBrightness() -> Float? {
        guard let get = DisplayServices.get else { return nil }
        var value: Float = 0
        guard get(CGMainDisplayID(), &value) == 0 else { return nil }
        return value
    }

    private static func writeBrightness(_ value: Float) -> Bool {
        guard let set = DisplayServices.set else { return false }
        return set(CGMainDisplayID(), value) == 0
    }
}

private enum DisplayServices {
    typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    typealias SetBrightness = @convention(c) (CGDirectDisplayID, Float) -> Int32

    static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
        RTLD_LAZY
    )

    static let get: GetBrightness? = {
        guard let handle, let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: GetBrightness.self)
    }()

    static let set: SetBrightness? = {
        guard let handle, let symbol = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: SetBrightness.self)
    }()
}
