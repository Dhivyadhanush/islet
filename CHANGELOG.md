# Changelog

## 1.1.1 — 12 November 2026

### Fixed

- Browser cover art that arrives after the track metadata is no longer dropped.
  The media helper compares the artwork payload, not only the track identifier.
- The player accent is sampled from the dominant hue of the cover instead of an
  RGB average, so colourful artwork no longer washes out to grey. Greyscale art
  still falls back to white.
- The menu-bar chip shows the cover thumbnail beside the waveform again.
- Bluetooth power is resolved with `dlsym`, so a future macOS that removes the
  private symbols cannot stop islet from launching.
- The one-shot media command/seek helper keeps its run loop alive long enough
  for MediaRemote to deliver the command.
- The legacy media poller no longer clears a track owned by the helper.
- The Server footer shows the Beszel sample time, not the fetch time.
- Longer server and paired-device lists scroll instead of clipping.
- Screen Time keeps counting passive media while the user is idle when audio is
  playing.
- `--beszel-save` accepts environment variables and stdin instead of requiring
  the password in argv.

### Added

- Pure-logic tests (`Tests/run.sh`), CI, and a tagged release workflow that
  builds the universal DMG and can update the Homebrew tap.
- Optional Developer ID signing and notarization in `build.sh`.
- Security policy and changelog.
- Accessibility labels for icon-only tab and header buttons.
- `--diagnose` prints artwork size and the derived accent colour.

### Changed

- `build.sh` preserves the previous DMG and requires `MAKE_DMG=1` to build one.
- The Homebrew cask quits the app on uninstall and zaps credentials and caches.
- Removed unused code and the stale Server "placeholder" description.

## 1.1.0 — 12 November 2026

- Connectivity tab with Wi-Fi and Bluetooth replaces the volume/brightness
  controls.
- Wi-Fi power, address and RSSI; Bluetooth power, paired devices and
  connect/disconnect.
- Bluetooth usage descriptions and snapshot preview.

## 1.0.3 — 12 November 2026

- Hide the now-playing chip for stale browser media sessions.
- Use CoreAudio per-process output to confirm playback.

## 1.0.2 — 12 November 2026

- Save closes the Settings window.

## 1.0.1 — 12 November 2026

- Explicit Start at login in the Settings Save flow.

## 1.0.0 — 10 November 2026

- Rename from lost_Island to islet and migrate credentials and the cask.
