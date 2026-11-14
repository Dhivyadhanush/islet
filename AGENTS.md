# AGENTS.md

Notes for anyone (human or agent) changing islet.

## Build and verify

```bash
Tests/run.sh                                # pure logic tests, no GUI
./build.sh                                  # native arch
ARCHS="arm64 x86_64" ./build.sh             # universal
MAKE_DMG=1 ./build.sh                       # build/islet-<version>.dmg
./build/islet.app/Contents/MacOS/islet --diagnose
./build/islet.app/Contents/MacOS/islet --snapshot build/snapshots
./build/islet.app/Contents/MacOS/islet --beszel-test
```

- `Tests/run.sh` compiles `Defaults.swift` + `BeszelParsing.swift` with a small
  assert runner. Anything that needs AppKit, SwiftUI or a window belongs in the
  snapshot/`--diagnose` path instead.
- `--diagnose` starts the services, waits 3 s, prints network/screen time/
  Wi-Fi/Bluetooth/media/artwork/battery/server/calendar state, then exits. The
  `artwork` line prints the cover size and the accent colour derived from it.
  Use it to verify the media helper and browser artwork.
- `--snapshot` renders every island state offscreen with sample data. It needs no
  Screen Recording permission. The PNGs in `docs/` come from this.
- Screen capture is often blocked by TCC; use snapshots instead of
  `screencapture`.
- The window is an `NSPanel` at `.statusBar`. Verify it with
  `CGWindowListCopyWindowInfo` (owner name `islet`, layer 25) rather than a
  screenshot.

## Architecture

| Path | Responsibility |
| --- | --- |
| `Sources/App/App.swift` | NSApplication entry, status item, lifecycle |
| `Sources/App/Snapshot.swift` | `--snapshot` renderer with sample data |
| `Sources/Island/IslandController.swift` | Panel geometry, hover, expand/collapse |
| `Sources/Island/IslandRootView.swift` | Notch silhouette, clip, transitions, dark scheme |
| `Sources/Island/IslandShape.swift` | Animatable top/bottom corner radii |
| `Sources/Island/ExpandedView.swift` | Tabs, battery, pin, gear |
| `Sources/Island/NowPlayingChip.swift` | Waveform chip left of the notch |
| `Sources/Island/Panes/*` | Music, network, screen time, connectivity, calendar, server |
| `Sources/Services/*` | Media, network, screen time, CoreAudio, EventKit, battery, Beszel |
| `Sources/Services/BeszelParsing.swift` | Pure Beszel metrics/date/interface mapping (no URLSession) |
| `Sources/Design/ArtworkPalette.swift` | Accent colour sampled from album art |
| `Tests/` | Pure logic tests (`Tests/run.sh`) |
| `.github/workflows/` | CI build + tagged release |
| `Sources/Services/AudioActivity.swift` | CoreAudio per-process output check |
| `Sources/Media/IsletMedia.m` | Objective-C dylib loaded by perl |
| `Sources/Media/islet-media.pl` | Loader/stream entry point |
| `Sources/Settings/*` | Settings window |

## Non-obvious constraints

1. **SwiftUI macros and Command Line Tools.** `@State` needs the
   `SwiftUIMacros` compiler plugin. `build.sh` adds the plugin path from the
   installed Xcode macOS platform. If the build fails with "plugin for module
   'SwiftUIMacros' not found", install full Xcode (or accept its license) and
   rebuild.
2. **MediaRemote on macOS 15.4+.** `MRMediaRemoteGetNowPlayingInfo` returns
   empty from an ordinary app process. The working path is the bundled
   `IsletMedia.dylib` loaded into `/usr/bin/perl`; MediaRemote trusts that
   Apple-signed process. Do not "simplify" this by calling MediaRemote directly
   from the app — browser media will silently disappear.
3. **The helper is a long-lived child process.** `MediaBridge` reads JSON lines
   from stdout. It restarts up to five times, then falls back to the legacy API.
   `NowPlaying.stop()` terminates it on quit. Browsers fetch Media Session
   artwork asynchronously, so the helper compares the artwork payload
   fingerprint (length ^ hash), not just the track identifier. Comparing only
   the identifier drops a cover that arrives one or two polls after the title.
   The app caches artwork by identifier. One-shot `command`/`seek` helpers pump
   the run loop for 0.8 s inside the dylib; without that MediaRemote drops the
   command because perl exits immediately. `MediaBridge` retains each one-shot
   `Process` until it terminates.
4. **Window geometry and tab wings.** The collapsed island is exactly the notch
   silhouette (square top, 12 pt bottom radius) so it disappears into the cutout.
   The expanded card is 620 pt wide: the tab strip is split 3/3 into the
   menu-bar wings left and right of the notch, with battery/pin/gear on the
   right wing and the pane below the notch. The panel is the island size plus
   10 pt on each side and below; the hover/tap handlers live on that padded
   wrapper. The margin exists so the spring overshoot is not clipped. Do not add
   a visible border; the design is intentionally borderless.
5. **No shadow.** `panel.hasShadow = false` keeps the resize animation cheap.
   The black shape is the whole visual.
6. **Dark mode.** The island forces `.environment(\.colorScheme, .dark)`.
   Without it, default SwiftUI text renders black on black.
7. **Notch detection.** `safeAreaInsets.top` + `auxiliaryTopLeftArea` /
   `auxiliaryTopRightArea`; fall back to a 150×30 floating pill on non-notch
   displays.
8. **Commands need a live process.** `MRMediaRemoteSendCommand` returns true but
   is only delivered while the calling process stays alive. islet is long-lived,
   so in-process commands work; a one-shot CLI must run a run loop for ~1 s.
9. **Screen Time is local.** macOS does not expose system Screen Time totals
   without Full Disk Access (Knowledge DB) or a DeviceActivity report extension.
   `ScreenTimeService` samples `NSWorkspace.frontmostApplication` every 5 s,
   excludes idle/sleep and system UI, and persists today's totals in
   UserDefaults. Do not present it as Apple's Screen Time number.
10. **Server is Beszel-backed and multi-system.** `BeszelClient.fetch` returns
    every system sorted by `created`; Server1 is first and the Pi below. The
    Server tab shows CPU/RAM/disk plus network `b` [sent, recv bytes/s] and the
    active `ni` interface (KB/s). Auth uses PocketBase
    (`POST /api/collections/users/auth-with-password`) and reads `systems` +
    `system_stats`. Hub URL/email/Access client ID live in UserDefaults; the
    password and Access secret live in a 0600 local credentials file under
    Application Support (Keychain ACLs do not survive ad-hoc rebuilds).
    Cloudflare Access service-token
    headers are supported. `--beszel-test` reads `BESZEL_URL`, `BESZEL_EMAIL`,
    `BESZEL_PASSWORD`, `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET`.
    `--beszel-save` accepts the same names as environment variables, or
    `--beszel-password-stdin`; avoid `--beszel-password` because argv is visible
    to local processes. `BeszelParsing` is pure and tested by `Tests/run.sh`.
    A system's `updatedAt` is the Beszel sample's `created` timestamp, not the
    fetch time, so an offline row shows how stale it is. The
    `NSAllowsLocalNetworking` ATS key permits local/tunnel HTTP for testing.
    `--beszel-save` writes the same config headlessly; it creates the 0600
    credentials file and can be run from any copy of the app.
    The Pi runs the armv7 agent as `beszel-agent.service`, configured in
    `/etc/beszel-agent.conf` with `KEY`, `HUB_URL=http://192.168.1.22:8090` and
    the per-system `TOKEN` from the `fingerprints` collection. Server metric
    visibility is controlled by `Defaults.serverCPU/RAM/Disk/Network` and the
    Settings → Server metrics checkboxes; `ServerPane` reads them via
    `@AppStorage`. The row is a weighted grid (CPU/RAM/Disk 1.0, NET 1.7) so
    removing a metric re-justifies the rest across the full width, and each
    system row is `maxHeight: .infinity` so the rows share the height. CPU, RAM
    and Disk render a 2.5 pt capsule bar under the value; NET has no bar. Bar
    colour is `< 40%` green, `40–79%` blue, `>= 80%` red (`Theme.loadLow/
    Medium/High`); the system dot is `Theme.online` / `Theme.offline`.
    Credentials live in `~/Library/Application Support/islet/credentials.json`
    with 0600 permissions so they survive native/universal rebuilds.
11. **Ad-hoc signing.** The app and the helper dylib are signed `-`. Rebuilding
    can reset TCC prompts; that is expected in development.
12. **Music accent + wave.** `ArtworkPalette` samples a 12×12 bitmap of the
    cover, finds the dominant hue bucket (a plain RGB average mixes
    complementary colours into grey), then clamps saturation/brightness so the
    hue stays legible on black. It caches by `ObjectIdentifier(NSImage)` and
    verifies the cached image identity, because addresses can be reused. A
    genuinely greyscale cover returns nil and `MusicPane` falls back to white.
    The pane's `PlayingWaveform` is a `TimelineView` + `Canvas` row of rounded
    bars (bar width 2, gap 1.8, heights driven by per-bar sine phases and an
    envelope); `active` freezes it when paused. Do not sample artwork on every
    frame without that cache.
13. **Now-playing chip left of the notch.** `NSStatusBar` only accepts items to
    the right of the notch, so `NowPlayingChipController` uses a second
    borderless `IslandPanel` at `.statusBar` level, 70×24 pt, positioned 6 pt
    left of the notch and vertically centred in the menu bar. It hosts a 16 pt
    cover thumbnail (or a music-note glyph) plus a white `PlayingWaveform`
    inside a black capsule, and is shown only when `track.isPlaying`, the island
    is visible and `state.expanded` is false; `AppDelegate` refreshes it from
    `NowPlaying.$track` and `IslandState.$expanded`. Clicking it selects the
    Music tab and calls `state.onExpandNow`. Do not add a status item for this;
    it cannot sit left of the notch.
14. **Settings are explicit-save.** `SettingsView` edits a `SettingsDraft` in
    `@State`; only the Save button (⌘S) writes `UserDefaults`. The island and
    panes use `@AppStorage`, so they update when Save lands. Save closes the
    Settings window on success and stays open only when the login item needs
    attention. Revert reloads the stored values. Do not bind the toggles
    straight to `@AppStorage` again or changes will leak before saving.
15. **Real playback state.** MediaRemote can keep `PlaybackRate = 1` for a
    browser tab whose audio has stopped (a stale media session). `NowPlaying`
    checks `AudioActivity.isOutputRunning(pid:bundleID:)` and forces the rate to
    0 after two consecutive silent samples (~3 s). The check matches the source
    PID or a process whose bundle ID has the app's bundle ID as a prefix, so
    Chromium/Firefox helper processes count. `nil` means unknown (older macOS or
    no audio client) and leaves the rate alone. Do not gate this on elapsed
    time; browsers often stop updating it. The helper and the legacy poller have
    separate miss counters: legacy must never clear a track the helper owns, and
    it stops as soon as a helper line arrives. `AudioActivity.isAnyOutputRunning()`
    also keeps Screen Time from discarding passive media as idle time.
16. **Start at login.** `LaunchAtLogin` wraps `SMAppService.mainApp`.
    `isRegistered` includes `.requiresApproval` so the toggle stays on while
    macOS waits for the user in System Settings → General → Login Items.
    Settings applies the change on Save; the menu-bar item toggles it
    immediately. The bundle ID must stay `dev.dhanuz.islet` for the existing
    login-item registration to survive a rename or rebuild.

17. **Connectivity.** `ConnectivityService` reads CoreWLAN for power, address and
    RSSI, and IOBluetooth for paired devices. `ssid()` is normally nil without
    Location permission, so the pane shows the IPv4 address and dBm instead.
    Bluetooth power uses the private
    `IOBluetoothPreferenceGet/SetControllerPowerState` symbols, resolved with
    `dlsym` rather than `@_silgen_name`: a missing symbol then disables the
    Bluetooth section instead of preventing islet from launching. Devices
    connect with `IOBluetoothDevice.openConnection()`, whose return code is
    surfaced as an error. The module keeps the `Defaults.showControls` key so
    existing preferences survive the rename to Connectivity.
18. **Secrets.** `--beszel-save` reads `BESZEL_URL`, `BESZEL_EMAIL`,
    `BESZEL_PASSWORD`, `CF_ACCESS_CLIENT_ID` and `CF_ACCESS_CLIENT_SECRET` from
    the environment, or `--beszel-password-stdin`. `--beszel-password` still
    works but warns: argv is visible to other local processes. Never add the
    password to logs or release notes.
19. **Settings text input.** islet is an accessory app with no visible menu bar,
    so `applicationDidFinishLaunching` installs a main menu with an Edit submenu
    (Undo/Redo/Cut/Copy/Paste/Select All). Without it, ⌘C/⌘V/⌘A are never routed
    to the Settings text fields. Keep the **Paste** button next to the Beszel
    password field as a fallback for clipboard managers and secure-input cases.
20. **Tests and CI.** `Tests/run.sh` builds the pure sources with a small
    assert runner. Keep `BeszelParsing` free of AppKit/URLSession so it stays
    testable. CI runs the tests, `build.sh` and `--snapshot`; a `v*` tag runs
    `release.yml`, which builds the universal DMG and updates the tap when
    `TAP_GITHUB_TOKEN` exists. Do not change `build.sh` to wipe `build/`: it
    keeps the previous DMG and refuses to overwrite one without
    `OVERWRITE_DMG=1`.

## Release checklist

1. Run `Tests/run.sh` and `./build.sh`.
2. Render snapshots and commit the updated `docs/preview-*.png`:
   `./build/islet.app/Contents/MacOS/islet --snapshot build/snapshots`.
3. Tag and push: `git tag v$VERSION && git push origin main --tags`.
   The `Release` workflow derives the version from the tag, builds the universal
   DMG, publishes it and (with `TAP_GITHUB_TOKEN`) updates the cask.
4. To build a release locally instead:
   `ARCHS="arm64 x86_64" MAKE_DMG=1 ./build.sh`, then
   `gh release create v$VERSION build/islet-$VERSION.dmg --generate-notes`.
5. If the tap was not updated automatically, set `version` and the
   `shasum -a 256` of the DMG in `Casks/islet.rb` and push the tap.
