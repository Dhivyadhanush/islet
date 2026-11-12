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

## Phase 6 — menu-bar tab wings + server metric checkboxes (7 Nov 2026)

Request: show only checked CPU/RAM/Disk/NET in the Server tab; put the tab strip
in the menu bar left and right of the notch; add install/using steps to GitHub.

- Expanded card width is now 620 pt. The tab strip is split 3/3 into the
  menu-bar wings: Music/Network/Screen Time left of the notch; Controls/Calendar/
  Server right; battery, pin and gear at the far right. The pane hangs below the
  notch.
- Added Settings → Server metrics checkboxes for CPU, RAM, Disk and Network.
  `ServerPane` reads `Defaults.serverCPU/RAM/Disk/Network` via `@AppStorage` and
  renders only checked items.
- Updated the README with an Installation section, a Using lost_Island section,
  the Server metrics checkboxes, and the Raspberry Pi agent steps.
- Version 0.7.1. The Beszel secret moved to `beszel.password.v2` / `beszel.accessSecret.v2` so a rebuilt app gets its own Keychain ACL instead of reusing an item bound to an older signature.

## Phase 7 — auto-justified server metrics + path Keychain ACL (7 Nov 2026)

Request: when a Server metric is removed, the remaining metrics should align and
fill the width.

- `ServerPane` now puts flexible `Spacer`s between the checked metrics, so
  CPU/RAM/Disk/Network fill the row; unchecking Network leaves CPU/RAM/Disk
  justified edge-to-edge. All unchecked leaves only the name/status line.
- Keychain items moved to v3 accounts (`beszel.password.v3` /
  `beszel.accessSecret.v3`) with a `SecAccess` trusted app path, so the Beszel
  credential survives rebuilds at `/Applications/lost_Island.app`.
- Version 0.7.3: the v3 path ACL did not survive the universal build; moved to v4 accounts with an allow-all `SecAccess` so the login-keychain item works across rebuilds.

## Phase 8 — 0600 credentials file (7 Nov 2026)

- Keychain ACLs did not survive native/universal rebuilds. Moved the Beszel
  password and Cloudflare Access secret to
  `~/Library/Application Support/lost_Island/credentials.json`, created with
  0600 permissions. URL/email/Access client ID remain in UserDefaults.
- `--beszel-save` writes the file headlessly; the app reads it on launch.
- Version 0.7.4.

## Phase 9 — percentage bars + vertical fill (7 Nov 2026)

Request: bars under CPU/RAM/Disk showing the percentage, and metric alignment
on both axes when metrics are added or removed.

- `ServerPane.metricsRow` is a weighted `GeometryReader` grid: CPU/RAM/Disk 1.0,
  NET 1.7. Adding/removing a metric recalculates cell widths, so the row fills
  edge-to-edge on the horizontal axis.
- Each system row uses `.frame(maxHeight: .infinity)`, so Server1 and Raspberry
  Pi split the pane height evenly; the footer stays at the bottom.
- CPU, RAM and Disk draw a 2.5 pt capsule bar under the value (filled fraction
  is the percentage); NET renders an empty 2.5 pt spacer so label baselines and
  row heights line up across all columns.
- Version 0.7.5.

## Phase 10 — larger metric labels (7 Nov 2026)

Request: the CPU/RAM/DISK/NET words were too small; make them bigger than the
number so they read clearly.

- `ServerPane.metric` label is now 12 pt bold (was 7.5 pt semibold) in full
  white with 0.8 tracking; the value is 9.5 pt monospaced at 62% opacity, so the
  label is the dominant element.
- The label/value baseline aligns via `HStack(alignment: .firstTextBaseline)`;
  the metric row grew from 22 pt to 34 pt to fit the taller text plus the bar.
- Version 0.7.6.

## Phase 11 — status colours (7 Nov 2026)

Request: green/red dot per system; bar colours by load; notch HUD for volume and
brightness.

- The per-system dot is `Theme.online` (green) when `isOnline`, `Theme.offline`
  (red) otherwise, with a soft glow.
- Bar fill is colour-coded: `< 40%` green (`Theme.loadLow`), `40–79%` blue
  (`Theme.loadMedium`), `>= 80%` red (`Theme.loadHigh`). The 40–50 band the
  request left open is treated as blue.
- Snapshot sample data now spans all three bands (Server1 18/62/88, Pi 7/31/46)
  so `docs/preview-server.png` shows the palette.
- Volume/brightness notch HUD: **not added.** macOS draws its own volume and
  brightness OSD through Control Center, and there is no public API to suppress
  it. Consuming the hardware keys needs an Accessibility event tap (volume can
  then be set via CoreAudio), but brightness has no public setter at all, so the
  pair cannot be done cleanly. Per the request, skipped rather than shipping a
  duplicate HUD.
- Version 0.7.7.

## Phase 12 — artwork accent, playing item, explicit save (7 Nov 2026)

Request: colour the player from the playing artwork; show a playing symbol in
the menu bar that disappears when playback stops; add a Save button to Settings.

- `ArtworkPalette` samples the cover into a 12×12 bitmap, weights saturated
  pixels, then clamps saturation/brightness for contrast on black. Cached by
  `ObjectIdentifier(NSImage)`. `MusicPane` uses it for the progress fill, scrub
  knob, play button, artwork ring/glow and a soft background wash; falls back to
  white without artwork.
- `AppDelegate` subscribes to `NowPlaying.$track` and creates a template
  `waveform` `NSStatusItem` while `track.isPlaying`, removing it on pause/stop.
  Clicking it selects the Music tab and shows the island. It is skipped in
  `--diagnose`.
- `SettingsView` now edits a `SettingsDraft` in `@State`; Save (⌘S) writes
  `UserDefaults`, Revert reloads them, and a transient "Saved" label confirms.
  Server has its own `Save & Test` as before.
- Snapshot uses a generated magenta/orange cover so the tint is visible in
  `docs/preview-music.png`.
- Version 0.8.0.

## Phase 13 — waveform + mini cover in the playing item (8 Nov 2026)

Clarified request: the "playing" animation should be an audio waveform combined
with a mini album-art thumbnail.

- The menu-bar item now renders a rounded mini cover (18 pt, aspect-filled)
  followed by a flowing sine wave. Six frames shift the wave phase; a 0.18 s
  `Timer` cycles them. Frames are rebuilt when `track.artwork` changes and use
  `NSColor.labelColor`, so the wave adapts to light/dark menu bars.
- `MusicPane` uses `PlayingWaveform` (TimelineView + Canvas) in the artwork
  accent colour; it flattens when paused.
- Replaced the temporary `EqualizerBars` with `PlayingWaveform`.
- Version 0.8.1.

## Phase 14 — now-playing chip left of the notch (8 Nov 2026)

Request: move the mini cover + waveform beside the menu bar, immediately left of
the notch.

- `NSStatusBar` cannot place third-party items left of the notch, so the item is
  now an island-owned borderless panel (`NowPlayingChipController`) at
  `.statusBar` level, 74×24 pt, positioned 6 pt left of the notch and vertically
  centred in the menu bar.
- It shows the mini cover + `PlayingWaveform`, opens the Music tab on click, and
  is hidden while paused, when the island expands, or when the island is hidden.
- Removed the previous right-side `NSStatusItem` and its six-frame image timer.
- Verified the panel frame at x=671, y=7 on the test display (island panel starts
  at 741 + 10 pt padding, so the chip sits 6 pt left of the notch) and confirmed
  it is offscreen while the track is paused.
- Version 0.8.2.

## Phase 15 — template-style bar waveform, no thumbnail (8 Nov 2026)

Request: use the waveform from `temblate.mp4` and drop the album thumbnail.

- `PlayingWaveform` is now a row of rounded bars (like the reference clip)
  instead of a sine line: 2 pt bars, 1.8 pt gaps, per-bar sine phases plus an
  envelope so the middle swells and the ends taper. `active` freezes it low.
- The menu-bar chip no longer shows the cover; it is a 52×24 black capsule with
  the white waveform only, still 6 pt left of the notch.
- The Music pane uses the same bar waveform in the artwork accent colour.
- Version 0.8.3.

## Phase 16 — rename to islet, 1.0.0 (10 Nov 2026)

Request: rename the app from lost_Island to islet, push the latest version, and
publish release notes.

- Product, bundle, executable and DMG are now `islet` (`build/islet.app`,
  `islet-<version>.dmg`). Bundle ID stays `dev.dhanuz.islet`, so UserDefaults
  survive the rename.
- Menu, Settings window, About text, accessibility labels and usage strings say
  islet. `--version` prints `islet <version>`.
- `CredentialStore` now writes to `~/Library/Application Support/islet/` and
  migrates (then removes) the old `lost_Island/credentials.json` on first load.
- The Homebrew cask is renamed to `islet` (`Casks/islet.rb`); the old
  `lost-island` cask is retired. README documents the one-time migration:
  `brew uninstall --cask lost-island` then `brew install --cask islet`.
- Version 1.0.0.

## Phase 17 — start at login in Save flow (12 Nov 2026)

Request: expose a "start at login" option.

- Settings → Behavior now says **Start at login** with a caption, and the value
  is part of `SettingsDraft`: Save applies it, Revert restores it.
- `LaunchAtLogin.isRegistered` treats `.requiresApproval` as on, so the toggle
  does not flip off while macOS waits for approval; a note points to System
  Settings → General → Login Items.
- Menu-bar item renamed to **Start at Login** and uses the same registered
  state.
- The existing login item already points at `/Applications/islet.app`; bundle ID
  is unchanged, so the registration survives the rename.
- Version 1.0.1.
