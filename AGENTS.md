# AGENTS.md

Notes for anyone (human or agent) changing islet.

## Build and verify

```bash
./build.sh                                  # native arch
ARCHS="arm64 x86_64" ./build.sh             # universal
./build/islet.app/Contents/MacOS/islet --diagnose
./build/islet.app/Contents/MacOS/islet --snapshot build/snapshots
./build/islet.app/Contents/MacOS/islet --beszel-test
```

- `--diagnose` starts the services, waits 3 s, prints network/screen time/
  volume/brightness/media/battery/server/calendar state, then exits. Use it to verify
  the media helper.
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
| `Sources/Island/Panes/*` | Music, network, screen time, controls, calendar, server |
| `Sources/Services/*` | Media, network, screen time, CoreAudio, EventKit, battery, Beszel |
| `Sources/Design/ArtworkPalette.swift` | Accent colour sampled from album art |
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
   `NowPlaying.stop()` terminates it on quit. Artwork is sent only when the
   content identifier changes; the app caches it.
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
    `BESZEL_PASSWORD`, `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET`. The
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
    cover, weights saturated pixels, then clamps saturation/brightness so the
    hue stays legible on black. It caches by `ObjectIdentifier(NSImage)`, and
    `MusicPane` falls back to white when there is no artwork. The pane's
    `PlayingWaveform` is a `TimelineView` + `Canvas` row of rounded bars (bar
    width 2, gap 1.8, heights driven by per-bar sine phases and an envelope);
    `active` freezes it when paused. Do not sample artwork on every frame
    without that cache.
13. **Now-playing chip left of the notch.** `NSStatusBar` only accepts items to
    the right of the notch, so `NowPlayingChipController` uses a second
    borderless `IslandPanel` at `.statusBar` level, positioned at
    `notchLeft - 52 - 6` and vertically centred in the menu bar. It hosts a
    white `PlayingWaveform` inside a black capsule (no artwork) and is shown
    only when `track.isPlaying`,
    the island is visible and `state.expanded` is false; `AppDelegate` refreshes
    it from `NowPlaying.$track` and `IslandState.$expanded`. Clicking it selects
    the Music tab and calls `state.onExpandNow`. Do not add a status item for
    this; it cannot sit left of the notch.
14. **Settings are explicit-save.** `SettingsView` edits a `SettingsDraft` in
    `@State`; only the Save button (⌘S) writes `UserDefaults`. The island and
    panes use `@AppStorage`, so they update when Save lands. Save closes the
    Settings window on success and stays open only when the login item needs
    attention. Revert reloads the stored values. Do not bind the toggles
    straight to `@AppStorage` again or changes will leak before saving.
15. **Start at login.** `LaunchAtLogin` wraps `SMAppService.mainApp`.
    `isRegistered` includes `.requiresApproval` so the toggle stays on while
    macOS waits for the user in System Settings → General → Login Items.
    Settings applies the change on Save; the menu-bar item toggles it
    immediately. The bundle ID must stay `dev.dhanuz.islet` for the existing
    login-item registration to survive a rename or rebuild.

## Release checklist

1. Bump `VERSION` in `build.sh` (and the Settings fallback version if needed).
2. `ARCHS="arm64 x86_64" ./build.sh`
3. `./build/islet.app/Contents/MacOS/islet --snapshot build/snapshots`
   and update `docs/preview-*.png`.
4. Build the DMG:
   `hdiutil create -volname "islet" -srcfolder build/dmg -ov -format UDZO build/islet-$VERSION.dmg`
5. `gh release create v$VERSION build/islet-$VERSION.dmg`
6. Update `Casks/islet.rb` in the `homebrew-islet` tap with the new version
   and `shasum -a 256` of the DMG.
