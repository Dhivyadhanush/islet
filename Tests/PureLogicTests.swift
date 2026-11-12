import Foundation

/// Small, dependency-free test runner for the parts of islet that do not need
/// AppKit, a window server or a network. Run with `Tests/run.sh`.
@main
struct PureLogicTests {
    static func main() {
        var failures = 0
        var checks = 0

        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            checks += 1
            if condition() {
                print("ok   \(message)")
            } else {
                failures += 1
                print("FAIL \(message)")
            }
        }

        // MARK: Formatters

        check(ByteFormat.bytes(0) == "0 KB", "zero bytes")
        check(ByteFormat.rate(0) == "0 KB/s", "zero rate")
        check(ByteFormat.bytes(1_500).contains("KB"), "bytes use a readable unit")
        check(ByteFormat.rate(2_400_000).hasSuffix("/s"), "rate keeps the /s suffix")

        check(ScreenTimeFormat.duration(0) == "0m", "zero duration")
        check(ScreenTimeFormat.duration(3_660) == "1h 1m", "hour and minute duration")
        check(ScreenTimeFormat.compact(59) == "1m", "short durations round up to a minute")
        check(ScreenTimeFormat.compact(3_600) == "1h 00m", "compact hour duration")

        // MARK: Beszel parsing

        let system: [String: Any] = [
            "id": "system-1",
            "name": "Server1",
            "status": "up",
            "host": "127.0.0.1",
            "info": [
                "cpu": 12.5,
                "mp": 50.0,
                "dp": 75.0,
                "u": 3_600.0,
                "c": 4,
                "t": 8,
                "h": "server1",
                "m": "Test CPU",
                "o": "Ubuntu",
            ],
        ]

        let stats: [String: Any] = [
            "created": "2026-11-12 14:00:00.123Z",
            "stats": [
                "mem": [8_000_000_000, 2_000_000_000],
                "d": 100.0,
                "du": 40.0,
                "b": [1_200.0, 3_400.0],
                "ni": [
                    "lo": [1, 1, 1, 1],
                    "wlan0": [10, 20, 30, 40],
                    "eth0": [5, 5, 5, 5],
                ],
            ],
        ]

        let metrics = BeszelParsing.metrics(
            system: system,
            statsRecord: stats,
            now: Date(timeIntervalSince1970: 0)
        )
        check(metrics.id == "system-1", "system id")
        check(metrics.name == "Server1", "system name")
        check(metrics.isOnline, "up maps to online")
        check(metrics.cpuPercent == 12.5, "cpu percentage")
        check(metrics.memoryPercent == 50, "memory percentage")
        check(metrics.memoryUsedBytes == 2_000_000_000, "memory used bytes")
        check(metrics.memoryTotalBytes == 8_000_000_000, "memory total bytes")
        check(metrics.diskPercent == 75, "disk percentage")
        check(metrics.diskUsedGB == 40, "disk used GB")
        check(metrics.diskTotalGB == 100, "disk total GB")
        check(metrics.networkSentBytesPerSecond == 1_200, "network sent")
        check(metrics.networkReceivedBytesPerSecond == 3_400, "network received")
        check(metrics.primaryInterface == "wlan0", "busiest interface is first")
        check(metrics.cores == 4 && metrics.threads == 8, "cpu topology")
        check(
            metrics.updatedAt.timeIntervalSince1970 > 1_700_000_000,
            "sample timestamp is used instead of the fetch time"
        )
        check(
            BeszelParsing.date("2026-11-12T14:00:00Z") != nil,
            "ISO-8601 timestamp is accepted"
        )
        check(
            BeszelParsing.date("2026-11-12 14:00:00Z") != nil,
            "PocketBase timestamp without milliseconds is accepted"
        )

        let stringInfoSystem: [String: Any] = [
            "info": "{\"cpu\": 5, \"mp\": 10, \"h\": \"pi\"}",
        ]
        let fixedNow = Date(timeIntervalSince1970: 1_800_000_000)
        let stringInfo = BeszelParsing.metrics(
            system: stringInfoSystem,
            statsRecord: nil,
            now: fixedNow
        )
        check(stringInfo.cpuPercent == 5, "JSON-string system info is decoded")
        check(stringInfo.name == "server", "missing name falls back")
        check(stringInfo.updatedAt == fixedNow, "missing sample uses now")

        let zeroTraffic: [String: Any] = [
            "eth0": [0, 0, 10, 10],
            "wlan0": [0, 0, 100, 100],
        ]
        check(
            BeszelParsing.interfaceList(zeroTraffic).first == "wlan0",
            "interface falls back to lifetime counters when idle"
        )
        check(
            BeszelParsing.interfaceList(["lo": [1, 2, 3, 4]]).isEmpty,
            "loopback is excluded"
        )

        print("")
        if failures == 0 {
            print("\(checks) checks passed")
        } else {
            print("\(failures) of \(checks) checks failed")
            exit(1)
        }
    }
}
