# Islet

A minimal, native dynamic island for the MacBook notch. Music, network, system
controls and calendar in one quiet black pill — built with SwiftUI and AppKit,
with no Electron, no web views and no analytics.

<p align="center">
  <img src="docs/preview-music.png" width="700" alt="Islet music player">
</p>

## What it does

- **Music that actually follows the system.** Apple Music, Spotify and browser
  playback (Safari, Chrome, Brave, Arc, Firefox) appear in the island with
  artwork, title, artist, source app, scrubbable progress and transport
  controls.
- **Network, per day.** Today's download/upload total, a live rate with a
  breathing indicator, and a seven-day bar chart. Counters are read from the
  kernel and stored locally.
- **Volume and brightness.** Thin, fast sliders backed by CoreAudio and
  DisplayServices. Mute with one click.
- **Calendar.** Today's events, an ongoing-event highlight, and a **Join**
  button when an event contains a meeting link.
- **Battery.** A tiny battery/charging readout in the expanded header.
- **Configurable.** Enable or disable any module, choose what the collapsed
  island shows, pin it open, or let it expand on hover.
- **Calm motion.** A spring-based morph with a sliding tab pill and a soft
  content scale. Turn on **Calm animations** for less overshoot.

<p align="center">
  <img src="docs/preview-network.png" width="340" alt="Network">
  <img src="docs/preview-controls.png" width="340" alt="Controls">
</p>
<p align="center">
  <img src="docs/preview-calendar.png" width="340" alt="Calendar">
  <img src="docs/preview-compact.png" width="340" alt="Collapsed island">
</p>

## Install with Homebrew

```bash
brew tap dhivyadhanush/islet
brew trust dhivyadhanush/islet
brew install --cask islet
```

On the first launch, right-click **Islet** in Applications and choose **Open**.
The app is ad-hoc signed, so macOS will not accept a double-click until you
approve it once. If macOS still blocks it, run:

```bash
sudo xattr -dr com.apple.quarantine /Applications/Islet.app
open /Applications/Islet.app
```

Islet lives in the menu bar. Hover the notch (or click the pill) to open it;
click anywhere outside to close it. The menu bar item has settings, launch at
login and quit.

## Browser media

macOS 15.4 stopped returning now-playing data to ordinary apps through the old
MediaRemote C API. Islet ships a small local helper (`IsletMedia.dylib`, loaded
by the Apple-signed `/usr/bin/perl`) that reads the system's now-playing
dictionary and streams it to the app. That is why browser playback now shows up.

- No network access, no analytics, no automation permission in the normal path.
- If a site does not publish Media Session metadata, macOS Control Center will
  not show it either, and Islet cannot invent it. Normal audio/video on Safari,
  Chrome, Brave, Arc and Firefox does publish it.
- If you ever see **Media → Fallback** in Settings, Islet could not start the
  helper and is using the older in-process API.

## Build from source

Requirements: macOS 14+, Xcode or Command Line Tools, and a Mac with a notch
for the full effect (on other displays Islet becomes a floating pill).

```bash
git clone https://github.com/dhivyadhanush/islet.git
cd islet
./build.sh
open build/Islet.app
```

Universal binary:

```bash
ARCHS="arm64 x86_64" ./build.sh
```

Useful diagnostics:

```bash
./build/Islet.app/Contents/MacOS/Islet --diagnose
./build/Islet.app/Contents/MacOS/Islet --snapshot build/snapshots
```

`--snapshot` renders the island offscreen to PNGs, which is how the images above
were produced.

## Permissions

| Feature | Permission |
| --- | --- |
| Music / browser media | None (system now-playing service) |
| Network | None |
| Volume | None (CoreAudio) |
| Brightness | None (DisplayServices, built-in display) |
| Calendar | Calendar access, requested when you tap **Connect** |

Islet is not sandboxed because brightness and the media helper need system
frameworks. It does not send data anywhere.

## Configuration

Open **Settings** from the menu bar or the gear in the island.

- Modules: Music, Network, Controls, Calendar.
- Compact view: Auto / Music / Network / Calendar.
- Behavior: expand on hover, battery in header, launch at login.
- Motion: Calm animations.
- Network: today's total and a reset button.
- Media: helper status.
- Permissions: calendar status and a shortcut to System Settings.

## Known limitations

- Daily network totals accumulate while Islet is running; the kernel counters
  are since boot, so usage while the app is closed is not backfilled.
- Brightness applies to the built-in display. External displays are left alone.
- The app is ad-hoc signed. A Developer ID build would remove the Gatekeeper
  warning; the source is here if you want to sign it yourself.
- Calendar access is read-only.

## Architecture

```
SwiftUI island (NSPanel, .statusBar, non-activating)
├── CompactView        one line: music / next event / network
├── ExpandedView       sliding tabs + battery + pin + settings
│   ├── MusicPane      MediaRemote helper + seek + source badge
│   ├── NetworkPane    getifaddrs counters + 7-day chart
│   ├── ControlsPane   CoreAudio volume + DisplayServices brightness
│   └── CalendarPane   EventKit + meeting-link Join
└── Services           NowPlaying, NetworkMonitor, SystemControls,
                       CalendarService, BatteryMonitor, MediaBridge
```

The window is exactly the island plus a 10 pt transparent margin so the spring
can overshoot without clipping. The top edge stays flush with the screen, which
is what makes it read as part of the notch.

## Credits

- The MediaRemote helper technique (loading a dylib into the system-signed perl
  process) is adapted from [nowplaying-cli](https://github.com/kirtan-shah/nowplaying-cli)
  and its `mediaremote-mini` adapter (BSD-3-Clause). See `NOTICE`.
- Design inspiration: Atoll, Boring.Notch and the iOS Dynamic Island.

## License

MIT. See `LICENSE`.
