# Session — Islet 0.2.0

**Date:** 6 November 2026
**Goal:** build a minimal, Atoll-style dynamic island for macOS with daily
network usage, a music view, volume/brightness controls, calendar events, and
user-configurable modules — then make the motion feel native, fix browser
playback, and ship it with a Homebrew install.

## What is in this repo

- A borderless, non-activating `NSPanel` attached to the notch (or a floating
  pill on non-notch displays).
- A one-line collapsed island and an expanded card with sliding tabs.
- Four modules: Music, Network, Controls, Calendar.
- Battery/charging in the header, meeting-link **Join** buttons, a live network
  pulse, a scrubbable music progress bar, and source-app badges.
- A settings window with module toggles, compact source, hover behavior,
  battery visibility, calm motion, launch at login, network reset, media helper
  status and calendar permissions.
- A menu bar item for show/hide, settings, launch at login and quit.
- A universal build script and a Homebrew cask/tap.

## The important fix: browser media

The first implementation called `MRMediaRemoteGetNowPlayingInfo` directly. It
worked for local players on older macOS but returned empty on this machine
(macOS 27) — including for browser playback. The cause is a macOS 15.4+ change:
MediaRemote no longer returns now-playing data to an ordinary app process.

The fix is `Sources/Media/IsletMedia.m` plus `islet-media.pl`. The app starts
`/usr/bin/perl` with the bundled dylib, and the dylib streams JSON lines from
MediaRemote. MediaRemote trusts the Apple-signed perl process, so Safari,
Chrome, Brave, Arc and Firefox all show up. Artwork is included only when the
content identifier changes; the app caches it. `MediaBridge` restarts the
helper on failure and `NowPlaying` falls back to the legacy API + AppleScript
if the helper cannot start.

Verified with Brave playing a local Media Session test page:

```
music    Browser Test Track — Brave Session [playing] Brave Browser
media    helper
battery  83%
```

## Motion and visual pass

- Borderless black shape, no hairline, no window shadow.
- `Theme.motion` spring (or a calmer spring when **Calm animations** is on).
- Content enters with opacity + a 0.96 scale anchored at the top.
- The selected tab is a white capsule that slides via `matchedGeometryEffect`.
- The panel is 10 pt larger than the island on each side and below so spring
  overshoot is not clipped; the top stays flush with the screen.
- Light haptics on expand/collapse/pin.
- The equalizer stops when the island expands (the compact view is removed),
  and the window shadow is off, which keeps the hover animation cheap.
- The island forces dark mode so default SwiftUI text cannot render black on
  black.

## Smart additions

- Battery/charging in the expanded header (IOKit power sources).
- The source app name and icon in the music pane (resolved from the now-playing
  PID).
- Drag the music progress bar to seek (`MRMediaRemoteSetElapsedTime`).
- Calendar rows with a **Join** button when the event has a URL (or a URL in its
  notes/location), detected with `NSDataDetector`.
- Live network pulse and a seven-day chart.
- Settings shows whether the media helper is connected or in fallback mode.

## Build / verify

```bash
cd ~/islet
ARCHS="arm64 x86_64" ./build.sh
./build/Islet.app/Contents/MacOS/Islet --diagnose
./build/Islet.app/Contents/MacOS/Islet --snapshot build/snapshots
```

`--snapshot` is the visual test harness. The PNGs in `docs/` are generated from
it. Screen Recording permission is not needed.

## Known state

- App version: 0.2.0, bundle id `dev.dhanuz.islet`.
- Ad-hoc signed; Gatekeeper may require
  `xattr -dr com.apple.quarantine /Applications/Islet.app`.
- Daily network totals accumulate while Islet runs.
- Brightness targets the built-in display.
- Calendar access is requested only when the user taps **Connect**.
- The SwiftUI `@State` macro requires the Xcode `SwiftUIMacros` plugin;
  `build.sh` points at the installed macOS platform plugin.

## Next steps

- Add a media source picker (Music/Spotify/browser priority).
- Optional weather or focus module.
- Per-module compact ordering instead of a single source picker.
- Sign with a Developer ID and notarize for a warning-free install.
- Persist network totals while the app is closed (boot-session counters).
