# AGENTS.md

Notes for anyone (human or agent) changing Islet.

## Build and verify

```bash
./build.sh                                  # native arch
ARCHS="arm64 x86_64" ./build.sh             # universal
./build/Islet.app/Contents/MacOS/Islet --diagnose
./build/Islet.app/Contents/MacOS/Islet --snapshot build/snapshots
```

- `--diagnose` starts the services, waits 3 s, prints network/volume/brightness/
  media/battery/calendar state, then exits. Use it to verify the media helper.
- `--snapshot` renders every island state offscreen with sample data. It needs no
  Screen Recording permission. The PNGs in `docs/` come from this.
- Screen capture is often blocked by TCC; use snapshots instead of
  `screencapture`.
- The window is an `NSPanel` at `.statusBar`. Verify it with
  `CGWindowListCopyWindowInfo` (owner name `Islet`, layer 25) rather than a
  screenshot.

## Architecture

| Path | Responsibility |
| --- | --- |
| `Sources/App/App.swift` | NSApplication entry, status item, lifecycle |
| `Sources/App/Snapshot.swift` | `--snapshot` renderer with sample data |
| `Sources/Island/IslandController.swift` | Panel geometry, hover, expand/collapse |
| `Sources/Island/IslandRootView.swift` | Shape, clip, transitions, dark scheme |
| `Sources/Island/CompactView.swift` | One-line collapsed content |
| `Sources/Island/ExpandedView.swift` | Tabs, battery, pin, gear |
| `Sources/Island/Panes/*` | Music, network, controls, calendar |
| `Sources/Services/*` | Media, network, CoreAudio, EventKit, battery |
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
4. **Window geometry.** The panel is the island size plus 10 pt on each side and
   below. The top is flush with `screen.frame.maxY`. The margin exists so the
   spring overshoot is not clipped. Do not add a visible border; the design is
   intentionally borderless.
5. **No shadow.** `panel.hasShadow = false` keeps the resize animation cheap.
   The black shape is the whole visual.
6. **Dark mode.** The island forces `.environment(\.colorScheme, .dark)`.
   Without it, default SwiftUI text renders black on black.
7. **Notch detection.** `safeAreaInsets.top` + `auxiliaryTopLeftArea` /
   `auxiliaryTopRightArea`; fall back to a 248×34 floating pill on non-notch
   displays.
8. **Commands need a live process.** `MRMediaRemoteSendCommand` returns true but
   is only delivered while the calling process stays alive. Islet is long-lived,
   so in-process commands work; a one-shot CLI must run a run loop for ~1 s.
9. **Network counters are 32-bit.** Accumulate deltas and treat a decrease as an
   interface reset. Only `en*` and `pdp_ip*` interfaces are counted so VPN
   tunnels do not double-count.
10. **Ad-hoc signing.** The app and the helper dylib are signed `-`. Rebuilding
    can reset TCC prompts; that is expected in development.

## Release checklist

1. Bump `VERSION` in `build.sh` (and the Settings fallback version if needed).
2. `ARCHS="arm64 x86_64" ./build.sh`
3. `./build/Islet.app/Contents/MacOS/Islet --snapshot build/snapshots` and update
   `docs/preview-*.png`.
4. `ditto -c -k --keepParent build/Islet.app build/Islet-$VERSION.zip`
5. `gh release create v$VERSION build/Islet-$VERSION.zip`
6. Update `Casks/islet.rb` in the `homebrew-islet` tap with the new version and
   `shasum -a 256` of the zip.
