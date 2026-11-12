import CoreAudio
import Foundation

/// Answers whether an app is actually writing audio to an output device.
///
/// MediaRemote can keep reporting `PlaybackRate = 1` for a browser tab that has
/// stopped making sound (a stale media session). CoreAudio's per-process output
/// flag is authoritative, so the player and the menu-bar chip use it to decide
/// whether a track is really playing.
enum AudioActivity {
    /// `nil` means "cannot tell": older macOS, or the app is not an audio client.
    static func isOutputRunning(pid: pid_t, bundleID: String) -> Bool? {
        guard #available(macOS 14.2, *) else { return nil }
        guard let processes = audioProcesses(), !processes.isEmpty else { return nil }

        var matched = false
        for process in processes {
            let processPID: pid_t = integerValue(process, kAudioProcessPropertyPID) ?? 0
            let processBundle = stringValue(process, kAudioProcessPropertyBundleID) ?? ""
            let running: UInt32 = integerValue(
                process,
                kAudioProcessPropertyIsRunningOutput
            ) ?? 0

            let pidMatches = pid > 0 && processPID == pid
            let bundleMatches = !bundleID.isEmpty
                && (processBundle == bundleID || processBundle.hasPrefix(bundleID + "."))
            guard pidMatches || bundleMatches else { continue }

            matched = true
            if running != 0 { return true }
        }

        // The app is connected to the audio system but every matching process
        // has its output stream stopped.
        return matched ? false : nil
    }

    /// True when any process is writing audio to an output device. Screen Time
    /// uses this to keep counting passive media playback while the user is idle.
    static func isAnyOutputRunning() -> Bool {
        guard #available(macOS 14.2, *) else { return false }
        guard let processes = audioProcesses() else { return false }
        for process in processes {
            let running: UInt32 = integerValue(
                process,
                kAudioProcessPropertyIsRunningOutput
            ) ?? 0
            if running != 0 { return true }
        }
        return false
    }

    @available(macOS 14.2, *)
    private static func audioProcesses() -> [AudioObjectID]? {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else {
            return nil
        }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }

        var objects = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &objects) == noErr else {
            return nil
        }
        return objects
    }

    @available(macOS 14.2, *)
    private static func integerValue<T: FixedWidthInteger>(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector
    ) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var result = T.zero
        var size = UInt32(MemoryLayout<T>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &result)
        return status == noErr ? result : nil
    }

    /// CFString properties are returned as a pointer; read it through
    /// `Unmanaged` so the generic integer helper never sees an object type.
    @available(macOS 14.2, *)
    private static func stringValue(
        _ object: AudioObjectID,
        _ selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var result: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(object, &address, 0, nil, &size, &result)
        guard status == noErr, let result else { return nil }
        return result.takeUnretainedValue() as String
    }
}
