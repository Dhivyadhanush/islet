# AGENTS.md

Notes for anyone (human or agent) changing lost_Island.

## Build and verify

```bash
./build.sh                                  # native arch
ARCHS="arm64 x86_64" ./build.sh             # universal
./build/lost_Island.app/Contents/MacOS/lost_Island --diagnose
./build/lost_Island.app/Contents/MacOS/lost_Island --snapshot build/snapshots
./build/lost_Island.app/Contents/MacOS/lost_Island --beszel-test
```

- `--diagnose` starts the services, waits 3 s, prints network/screen time/
  volume/brightness/media/battery/server/calendar state, then exits. Use it to verify
  the media helper.
- `--snapshot` renders every island state offscreen with sample data. It needs no
  Screen Recording permission. The PNGs in `docs/` come from this.
- Screen capture is often blocked by TCC; use snapshots instead of
  `screencapture`.
- The window is an `NSPanel` at `.statusBar`. Verify it with
  `CGWindowListCopyWindowInfo` (owner name `lost_Island`, layer 25) rather than a
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
| `Sources/Island/Panes/*` | Music, network, screen time, controls, calendar, server |
| `Sources/Services/*` | Media, network, screen time, CoreAudio, EventKit, battery, Beszel |
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
4. **Window geometry.** The collapsed island is exactly the notch silhouette
   (square top, 12 pt bottom radius) so it disappears into the cutout. The panel
   is the island size plus 10 pt on each side and below; the hover/tap handlers
   live on that padded wrapper, so hovering just under the notch works. The
   expanded state keeps the top flush. The margin exists so the spring overshoot
   is not clipped. Do not add a visible border; the design is intentionally
   borderless.
5. **No shadow.** `panel.hasShadow = false` keeps the resize animation cheap.
   The black shape is the whole visual.
6. **Dark mode.** The island forces `.environment(\.colorScheme, .dark)`.
   Without it, default SwiftUI text renders black on black.
7. **Notch detection.** `safeAreaInsets.top` + `auxiliaryTopLeftArea` /
   `auxiliaryTopRightArea`; fall back to a 150×30 floating pill on non-notch
   displays.
8. **Commands need a live process.** `MRMediaRemoteSendCommand` returns true but
   is only delivered while the calling process stays alive. lost_Island is long-lived,
   so in-process commands work; a one-shot CLI must run a run loop for ~1 s.
9. **Screen Time is local.** macOS does not expose system Screen Time totals
   without Full Disk Access (Knowledge DB) or a DeviceActivity report extension.
   `ScreenTimeService` samples `NSWorkspace.frontmostApplication` every 5 s,
   excludes idle/sleep and system UI, and persists today's totals in
   UserDefaults. Do not present it as Apple's Screen Time number.
10. **Server is Beszel-backed.** `BeszelClient` authenticates to PocketBase
    (`POST /api/collections/users/auth-with-password`) and reads `systems` plus
    `system_stats`. The hub URL/email/Access client ID live in UserDefaults; the
    password and Access secret live in Keychain. Cloudflare Access service-token
    headers are supported. `--beszel-test` reads `BESZEL_URL`, `BESZEL_EMAIL`,
    `BESZEL_PASSWORD`, `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET`. The
    `NSAllowsLocalNetworking` ATS key permits local/tunnel HTTP for testing.
11. **Ad-hoc signing.** The app and the helper dylib are signed `-`. Rebuilding
    can reset TCC prompts; that is expected in development.

## Release checklist

1. Bump `VERSION` in `build.sh` (and the Settings fallback version if needed).
2. `ARCHS="arm64 x86_64" ./build.sh`
3. `./build/lost_Island.app/Contents/MacOS/lost_Island --snapshot build/snapshots`
   and update `docs/preview-*.png`.
4. Build the DMG:
   `hdiutil create -volname "lost_Island" -srcfolder build/dmg -ov -format UDZO build/lost_Island-$VERSION.dmg`
5. `gh release create v$VERSION build/lost_Island-$VERSION.dmg`
6. Update `Casks/lost-island.rb` in the `homebrew-islet` tap with the new version
   and `shasum -a 256` of the DMG.
