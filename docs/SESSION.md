# Session — lost_Island

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

## Phase 2 — notch merge, Screen Time, Server placeholder (7 Nov 2026)

Request: remove the network data readout that extended the notch; let the
collapsed island merge with the notch; add Screen Time; add a Server tab that
stays a TODO until the integration is specified.

Changes:

- Removed the Network module (`NetworkMonitor`, `NetworkPane`, the compact
  readout, and the compact-source setting).
- The collapsed island is now exactly the notch silhouette: square top, 12 pt
  bottom radius, no text, no extra width. The panel is the notch plus a 10 pt
  transparent hover margin, and the hover/tap handlers live on that padded
  wrapper, so hovering the notch (or just below it) opens the card.
- Added `ScreenTimeService`: samples the frontmost app every 5 s, excludes
  idle/sleep and system UI, persists today's totals, and renders a total,
  stacked app bar and top three apps. This is a local estimate — system Screen
  Time needs Full Disk Access or a DeviceActivity report extension.
- Added `ServerStatusService` + `ServerPane`: a polished placeholder with the
  `Status` enum (`notConfigured`, `checking`, `online(latency)`, `offline`) and
  a single `check()` integration point. The settings window has a Server
  section explaining that the integration is pending.
- Tabs are now Music, Screen Time, Controls, Calendar, Server.
- The notch shape uses `IslandShape` with animatable corner radii, so the
  collapse/expand morphs smoothly from the notch silhouette into the card.
- Version 0.3.0; snapshots regenerated; docs and AGENTS updated.

Current state:

- App version 0.3.0, bundle id `dev.dhanuz.islet`.
- Collapsed window on this Mac: 228×48 including the hover margin; island
  208×37.5 (the notch).
- Screen Time persists under `islet.screentime.v1`.
- Server status is `notConfigured` until the user provides the integration.
- Release 0.3.0 + cask update pending at the time this section was written.

Next:

- Wire the user's server details into `ServerStatusService.check()`.
- Optionally read system Screen Time with Full Disk Access, or ship a
  DeviceActivity report extension.
- Add a per-app detail view and a seven-day Screen Time history.

## Phase 3 — lost_Island rebrand, network back on hover, solo animated logo (7 Nov 2026)

Request: keep the network data usage in the hover card, rename the app to
lost_Island, and make the logo a solo animated island.

Changes:

- Restored the Network module (`NetworkMonitor`, `NetworkPane`) and added it back
  to the expanded tabs and Settings. The collapsed island remains the notch
  silhouette; the data usage is only visible when the card is open.
- Renamed the app bundle, executable, display name, menu items, Settings title
  and About text to **lost_Island**. The bundle id remains `dev.dhanuz.islet`
  so preferences, network history, Screen Time history and TCC survive.
- New solo-island brand art: a white island with a black notch and animated
  equalizer bars, no tile/background. The app icon is a transparent solo island;
  `docs/logo.gif` is an animated version; Settings > About uses an animated
  SwiftUI mark; the menu bar uses a template island silhouette.
- Tabs: Music, Network, Screen Time, Controls, Calendar, Server.
- Version 0.4.0. Cask renamed to `lost-island`; the tap stays
  `dhivyadhanush/islet`.

Current state:

- App bundle: `lost_Island.app`; executable `lost_Island`; version 0.4.0.
- Collapsed window on this Mac: 228×48 including the hover margin; island
  208×37.5 (the notch).
- Network data usage is back in the hover card, not in the collapsed notch.
- Screen Time remains a local frontmost-app estimate.
- Server status remains a placeholder; `ServerStatusService.check()` is the
  integration point.

## Phase 4 — Beszel server integration (7 Nov 2026)

Request: explain how the server monitor runs on the domain and wire it into the
island.

- Added `BeszelClient`: PocketBase auth, `systems` list, latest `system_stats`,
  optional Cloudflare Access service-token headers. It caches the auth token for
  10 minutes and retries once on 401.
- Added `Keychain` for the Beszel password and Access secret; URL/email/client ID
  live in UserDefaults.
- `ServerStatusService` polls every 30 s, keeps the last good metrics, and maps
  Beszel's `up`/`down` status to the tab.
- `ServerPane` now renders an online dashboard: server name, CPU %, RAM % and
  used/total, disk % and used/total, uptime, OS, last update, refresh button.
  The unconfigured state is a setup prompt.
- Settings → Server (Beszel): hub URL, read-only email/password, optional
  Cloudflare Access Client ID/Secret, Save & Test, Refresh.
- Added `--beszel-test` with `BESZEL_URL`, `BESZEL_EMAIL`, `BESZEL_PASSWORD`,
  `CF_ACCESS_CLIENT_ID`, `CF_ACCESS_CLIENT_SECRET`.
- Added `NSAllowsLocalNetworking` to Info.plist for the SSH tunnel / LAN test.
- Domain path: add `beszel.dhanush-vijay.uk` → `http://172.17.0.1:8090` in the
  Cloudflare Tunnel, create a read-only Beszel user, optionally add Cloudflare
  Access + a service token, then fill in Settings → Server.
- Version 0.5.0.

Verified: unconfigured error path and a live auth-failure response through the
SSH tunnel (`Beszel login failed. Failed to authenticate.`). The success path
needs the read-only Beszel user.

### Live configuration (7 Nov 2026)

- The domain `https://beszel.dhanush-vijay.uk` is live and returns the Beszel UI.
- The installed app was configured through `--beszel-save` (0.5.1 helper); the
  hub URL and account are in UserDefaults, the password is in Keychain.
- `--diagnose` reports `server online`; the Beszel client reports
  `Server1 [up]`, CPU ~3%, RAM ~27%, disk ~22%, uptime ~8d 11h.
- The account used is an admin account; a read-only Beszel user is still the
  recommended follow-up for daily use.

## Phase 5 — Raspberry Pi agent + multi-system/network Server tab (7 Nov 2026)

Request: install the monitor on the Raspberry Pi as well, show it below Server1,
and add network details.

- Installed Beszel agent 0.21.1 for armv7 on `Rasberry` (Raspbian 13) from the
  `.deb`; systemd service `beszel-agent.service` is enabled.
- Config `/etc/beszel-agent.conf` (0600): `KEY` (hub public key),
  `HUB_URL=http://192.168.1.22:8090`, `TOKEN` (per-system fingerprint token).
- Created the `Raspberry Pi` system + `fingerprints` token through the admin
  API. The agent connects to the hub over WebSocket and also exposes its SSH
  server on 45876.
- Beszel now reports two systems: `Server1` and `Raspberry Pi`, both `up`.
- `BeszelClient.fetch` returns all systems sorted by `created`; the Server tab
  lists Server1 first and Raspberry Pi below.
- Network details use `b` [sent, received bytes/s] and `ni` interface counters;
  the active interface is chosen and shown as e.g. `wlan0 ↓ 3.1 KB/s ↑ 3.6 KB/s`.
- Version 0.6.0.
