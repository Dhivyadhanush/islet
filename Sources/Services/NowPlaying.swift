import AppKit
import Combine
import Darwin

/// Now-playing data.
///
/// Primary path: the bundled Perl + IsletMedia.dylib helper. On macOS 15.4+
/// MediaRemote only returns browser media to an Apple-signed process, so the
/// helper streams JSON lines and this class turns them into a Track.
///
/// Fallbacks: the legacy MediaRemote C API (older macOS) and a small
/// AppleScript probe for Music/Spotify if both fail.
@MainActor
final class NowPlaying: ObservableObject {
    struct Track {
        var title: String = ""
        var artist: String = ""
        var album: String = ""
        var duration: Double = 0
        var elapsed: Double = 0
        var rate: Double = 0
        var artwork: NSImage?
        var source: String = ""
        var sourceIcon: NSImage?
        var isPlaying: Bool { rate > 0.01 }
    }

    enum Command: Int32 {
        case play = 0
        case pause = 1
        case toggle = 2
        case next = 4
        case previous = 5
    }

    @Published private(set) var track: Track?
    @Published private(set) var position: Double = 0
    @Published private(set) var bridgeActive = false
    @Published private(set) var usingFallback = false

    private let bridge = MediaBridge()
    private var tickTimer: Timer?
    private var legacyTimer: Timer?
    private var lastSync: Date?
    private var misses = 0
    private var artworkCache: [String: NSImage] = [:]
    private var legacyStarted = false
    private var lastLineAt: Date?
    private var scriptInFlight = false
    private var lastScript = Date.distantPast

    func start() {
        guard tickTimer == nil else { return }
        startTicking()

        bridge.start(
            onLine: { [weak self] info in
                self?.ingest(info)
            },
            onFailure: { [weak self] in
                self?.startLegacy()
            }
        )

        // If the helper cannot start or never writes a line, fall back to the
        // in-process API so older macOS versions still work.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, self.lastLineAt == nil else { return }
            self.startLegacy()
        }
    }

    func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        legacyTimer?.invalidate()
        legacyTimer = nil
        bridge.stop()
    }

    func toggle() { send(.toggle) }
    func next() { send(.next) }
    func previous() { send(.previous) }

    func send(_ command: Command) {
        let sent = MediaRemote.send?(command.rawValue, nil) ?? false
        if !sent {
            bridge.send(command: Int(command.rawValue))
        }

        if command == .toggle, var current = track {
            let now = position
            current.elapsed = now
            current.rate = current.rate > 0 ? 0 : 1
            track = current
            lastSync = Date()
        }
    }

    func seek(to time: Double) {
        guard let current = track, current.duration > 0 else { return }
        let clamped = min(max(time, 0), current.duration)
        if let setElapsed = MediaRemote.setElapsedTime {
            setElapsed(clamped)
        } else {
            bridge.seek(to: clamped)
        }
        position = clamped
        var updated = current
        updated.elapsed = clamped
        track = updated
        lastSync = Date()
    }

    /// Used by `--snapshot` to render the design without a live player.
    func previewSet(_ track: Track?, position: Double = 0) {
        self.track = track
        self.position = position
        self.lastSync = Date()
    }

    // MARK: - Ticking

    private func startTicking() {
        let tick = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(tick, forMode: .common)
        tickTimer = tick
    }

    private func tick() {
        guard let current = track, current.rate > 0, let sync = lastSync else { return }
        let projected = current.elapsed + Date().timeIntervalSince(sync) * current.rate
        position = current.duration > 0 ? min(projected, current.duration) : projected
    }

    // MARK: - Helper stream

    private func ingest(_ info: [String: Any]) {
        lastLineAt = Date()
        bridgeActive = true

        let title = string(info["kMRMediaRemoteNowPlayingInfoTitle"])
        guard !title.isEmpty else {
            misses += 1
            if misses >= 3 {
                track = nil
                position = 0
            }
            return
        }

        let artist = string(info["kMRMediaRemoteNowPlayingInfoArtist"])
        let album = string(info["kMRMediaRemoteNowPlayingInfoAlbum"])
        let duration = max(number(info["kMRMediaRemoteNowPlayingInfoDuration"]), 0)
        let elapsed = max(number(info["kMRMediaRemoteNowPlayingInfoElapsedTime"]), 0)
        let rate = max(number(info["kMRMediaRemoteNowPlayingInfoPlaybackRate"]), 0)
        let timestamp = number(info["kMRMediaRemoteNowPlayingInfoTimestamp"])

        let identifier = string(info["kMRMediaRemoteNowPlayingInfoContentItemIdentifier"])
            .isEmpty
            ? "\(title)|\(artist)|\(album)"
            : string(info["kMRMediaRemoteNowPlayingInfoContentItemIdentifier"])

        var artwork = artworkCache[identifier]
        if let base64 = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? String,
           let data = Data(base64Encoded: base64),
           let image = NSImage(data: data) {
            artwork = image
            artworkCache[identifier] = image
            if artworkCache.count > 8 {
                artworkCache.removeAll()
                artworkCache[identifier] = image
            }
        }

        var source = ""
        var sourceIcon: NSImage?
        if let pid = info["_pid"] as? Int, pid > 0,
           let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
            source = app.localizedName ?? ""
            sourceIcon = app.icon
        }

        let updated = Track(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsed: elapsed,
            rate: rate,
            artwork: artwork,
            source: source,
            sourceIcon: sourceIcon
        )

        let changed = track?.title != updated.title
            || track?.artist != updated.artist
            || track?.album != updated.album
            || track?.duration != updated.duration
            || track?.rate != updated.rate
            || track?.source != updated.source
            || track?.artwork !== updated.artwork

        if changed {
            track = updated
        }
        position = elapsed
        lastSync = timestamp > 1 ? Date(timeIntervalSince1970: timestamp) : Date()
        misses = 0
    }

    // MARK: - Legacy fallback

    private func startLegacy() {
        guard !legacyStarted else { return }
        legacyStarted = true
        usingFallback = true
        refresh()

        let poll = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        RunLoop.main.add(poll, forMode: .common)
        legacyTimer = poll
    }

    private func refresh() {
        guard let getInfo = MediaRemote.getInfo else {
            fallbackIfNeeded()
            return
        }
        getInfo(DispatchQueue.main) { [weak self] info in
            guard let self else { return }
            if let dictionary = info as? [String: Any], !dictionary.isEmpty {
                self.consumeLegacy(dictionary)
            } else {
                self.misses += 1
                if self.misses >= 3 {
                    self.track = nil
                    self.position = 0
                    self.fallbackIfNeeded()
                }
            }
        }
    }

    private func consumeLegacy(_ info: [String: Any]) {
        let title = string(info["kMRMediaRemoteNowPlayingInfoTitle"])
        guard !title.isEmpty else { return }
        let artist = string(info["kMRMediaRemoteNowPlayingInfoArtist"])
        let album = string(info["kMRMediaRemoteNowPlayingInfoAlbum"])
        let duration = max(number(info["kMRMediaRemoteNowPlayingInfoDuration"]), 0)
        let elapsed = max(number(info["kMRMediaRemoteNowPlayingInfoElapsedTime"]), 0)
        let rate = max(number(info["kMRMediaRemoteNowPlayingInfoPlaybackRate"]), 0)

        var artwork = track?.artwork
        if let data = info["kMRMediaRemoteNowPlayingInfoArtworkData"] as? Data,
           let image = NSImage(data: data) {
            artwork = image
        }

        track = Track(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            elapsed: elapsed,
            rate: rate,
            artwork: artwork,
            source: "",
            sourceIcon: nil
        )
        position = elapsed
        lastSync = Date()
        misses = 0
    }

    private func fallbackIfNeeded() {
        guard track == nil, !scriptInFlight, Date().timeIntervalSince(lastScript) > 10 else { return }

        let running = NSWorkspace.shared.runningApplications
        let app: String?
        if running.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) {
            app = "Music"
        } else if running.contains(where: { $0.bundleIdentifier == "com.spotify.client" }) {
            app = "Spotify"
        } else {
            app = nil
        }
        guard let app else { return }

        scriptInFlight = true
        lastScript = Date()
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = Self.query(app)
            DispatchQueue.main.async {
                guard let self else { return }
                self.scriptInFlight = false
                guard let result, self.track == nil else { return }
                self.track = result
                self.position = result.elapsed
                self.lastSync = Date()
            }
        }
    }

    nonisolated private static func query(_ app: String) -> Track? {
        let script: String
        if app == "Music" {
            script = """
            tell application "Music"
                if player state is stopped then return ""
                set t to current track
                return (name of t) & "|~|" & (artist of t) & "|~|" & (album of t) & "|~|" & (duration of t) & "|~|" & (player position) & "|~|" & (player state as text)
            end tell
            """
        } else {
            script = """
            tell application "Spotify"
                if player state is stopped then return ""
                set t to current track
                return (name of t) & "|~|" & (artist of t) & "|~|" & (album of t) & "|~|" & ((duration of t) / 1000) & "|~|" & (player position) & "|~|" & (player state as text)
            end tell
            """
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let raw = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: "|~|")
        guard parts.count >= 6 else { return nil }

        let state = parts[5].lowercased()
        guard state != "stopped" else { return nil }
        return Track(
            title: parts[0],
            artist: parts[1],
            album: parts[2],
            duration: Double(parts[3]) ?? 0,
            elapsed: Double(parts[4]) ?? 0,
            rate: state == "playing" ? 1 : 0,
            artwork: nil,
            source: app,
            sourceIcon: nil
        )
    }

    // MARK: - Helpers

    private func string(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let text = value as? NSString { return text as String }
        return ""
    }

    private func number(_ value: Any?) -> Double {
        if let number = value as? NSNumber { return number.doubleValue }
        if let number = value as? Double { return number }
        if let number = value as? Int { return Double(number) }
        return 0
    }
}

// MARK: - MediaRemote (legacy API and commands)

private enum MediaRemote {
    typealias GetInfo = @convention(c) (DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void) -> Void
    typealias Send = @convention(c) (Int32, CFDictionary?) -> Bool
    typealias SetElapsed = @convention(c) (Double) -> Void

    static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
        RTLD_LAZY
    )

    static let getInfo: GetInfo? = {
        guard let handle, let symbol = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else { return nil }
        return unsafeBitCast(symbol, to: GetInfo.self)
    }()

    static let send: Send? = {
        guard let handle, let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else { return nil }
        return unsafeBitCast(symbol, to: Send.self)
    }()

    static let setElapsedTime: SetElapsed? = {
        guard let handle, let symbol = dlsym(handle, "MRMediaRemoteSetElapsedTime") else { return nil }
        return unsafeBitCast(symbol, to: SetElapsed.self)
    }()
}
