import Foundation

/// Runs the bundled Perl + dylib helper that streams MediaRemote now-playing
/// data as JSON lines. The helper is what makes browser playback (Safari,
/// Chrome, Brave, Arc, Firefox) visible on macOS 15.4 and later.
final class MediaBridge {
    private var process: Process?
    private var pipe: Pipe?
    private var buffer = Data()
    private let parseQueue = DispatchQueue(label: "dev.dhanuz.islet.media.parse")
    private var onLine: (([String: Any]) -> Void)?
    private var onFailure: (() -> Void)?
    private var stopping = false
    private var restarts = 0

    var isRunning: Bool { process?.isRunning == true }

    func start(
        onLine: @escaping ([String: Any]) -> Void,
        onFailure: @escaping () -> Void
    ) {
        self.onLine = onLine
        self.onFailure = onFailure
        launch()
    }

    private func launch() {
        guard !stopping else { return }
        guard let resources = Bundle.main.resourceURL else {
            onFailure?()
            return
        }
        let script = resources.appendingPathComponent("islet-media.pl")
        let library = resources.appendingPathComponent("IsletMedia.dylib")
        guard FileManager.default.fileExists(atPath: script.path),
              FileManager.default.fileExists(atPath: library.path) else {
            onFailure?()
            return
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script.path, library.path, "stream"]
        let output = Pipe()
        task.standardOutput = output
        task.standardError = Pipe()

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data)
        }

        task.terminationHandler = { [weak self] _ in
            guard let self, !self.stopping else { return }
            self.process = nil
            self.pipe = nil
            self.restarts += 1
            if self.restarts <= 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.launch() }
            } else {
                DispatchQueue.main.async { self.onFailure?() }
            }
        }

        do {
            try task.run()
            process = task
            pipe = output
        } catch {
            onFailure?()
        }
    }

    private func consume(_ data: Data) {
        parseQueue.async { [weak self] in
            guard let self else { return }
            self.buffer.append(data)
            while let newline = self.buffer.firstIndex(of: 0x0A) {
                let line = self.buffer[self.buffer.startIndex..<newline]
                self.buffer.removeSubrange(self.buffer.startIndex...newline)
                guard !line.isEmpty,
                      let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
                else { continue }
                DispatchQueue.main.async {
                    self.onLine?(object)
                }
            }
        }
    }

    func send(command: Int) {
        runOneShot(mode: "command", argument: String(command))
    }

    func seek(to time: Double) {
        runOneShot(mode: "seek", argument: String(time))
    }

    private func runOneShot(mode: String, argument: String) {
        guard let resources = Bundle.main.resourceURL else { return }
        let script = resources.appendingPathComponent("islet-media.pl")
        let library = resources.appendingPathComponent("IsletMedia.dylib")
        guard FileManager.default.fileExists(atPath: script.path) else { return }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        task.arguments = [script.path, library.path, mode, argument]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        try? task.run()
    }

    func stop() {
        stopping = true
        pipe?.fileHandleForReading.readabilityHandler = nil
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        pipe = nil
    }

    deinit {
        stop()
    }
}
