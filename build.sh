#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/islet.app"
EXEC="islet"
BUILD="${BUILD:-1}"
ARCHS="${ARCHS:-$(uname -m)}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
MAKE_DMG="${MAKE_DMG:-0}"
DMG_DIR="${DMG_DIR:-build}"
OVERWRITE_DMG="${OVERWRITE_DMG:-0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

# Use the latest release tag when VERSION is not supplied, so a tagged release
# built in CI cannot accidentally ship the previous version number.
if [ -z "${VERSION:-}" ]; then
  VERSION="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
  VERSION="${VERSION#v}"
fi
VERSION="${VERSION:-1.1.0}"

rm -rf "$APP"
rm -f build/"$EXEC"-*
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$DMG_DIR"

SOURCES=$(find Sources -name '*.swift' | sort)

# SwiftUI's @State lives in a compiler plugin shipped with the macOS platform.
# Command Line Tools alone does not include it; use the plugin from Xcode when
# it is present so the project builds without opening Xcode.
PLUGIN_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins"
PLUGIN_FLAGS=()
if [ -d "$PLUGIN_PATH" ]; then
  PLUGIN_FLAGS=(-plugin-path "$PLUGIN_PATH")
fi

SLICES=()
for arch in $ARCHS; do
  echo "Compiling $arch..."
  swiftc -O -parse-as-library \
    -target "$arch-apple-macos14.0" \
    "${PLUGIN_FLAGS[@]}" \
    -framework EventKit \
    -framework CoreAudio \
    -framework AudioToolbox \
    -framework ServiceManagement \
    $SOURCES \
    -o "build/$EXEC-$arch"
  SLICES+=("build/$EXEC-$arch")
done

if [ "${#SLICES[@]}" -gt 1 ]; then
  lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/$EXEC"
else
  cp "${SLICES[0]}" "$APP/Contents/MacOS/$EXEC"
fi

if [ -f Resources/AppIcon.icns ]; then
  cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

# Browser media helper. MediaRemote only returns browser now-playing data to
# an Apple-signed process, so the app loads this dylib through /usr/bin/perl.
if [ -f Sources/Media/IsletMedia.m ]; then
  echo "Building media helper..."
  MEDIA_ARCH_FLAGS=()
  for arch in $ARCHS; do
    MEDIA_ARCH_FLAGS+=(-arch "$arch")
  done
  clang -dynamiclib -O2 -fobjc-arc \
    "${MEDIA_ARCH_FLAGS[@]}" \
    -mmacosx-version-min=14.0 \
    -framework Foundation \
    -framework AppKit \
    Sources/Media/IsletMedia.m \
    -o "$APP/Contents/Resources/IsletMedia.dylib"
  cp Sources/Media/islet-media.pl "$APP/Contents/Resources/islet-media.pl"
  chmod +x "$APP/Contents/Resources/islet-media.pl"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.dhanuz.islet</string>
  <key>CFBundleName</key><string>islet</string>
  <key>CFBundleDisplayName</key><string>islet</string>
  <key>CFBundleExecutable</key><string>islet</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key><true/>
  </dict>
  <key>NSCalendarsFullAccessUsageDescription</key><string>islet shows today's events in the notch. Your calendar is read on this Mac only and is never sent anywhere.</string>
  <key>NSCalendarsUsageDescription</key><string>islet shows today's events in the notch. Your calendar is read on this Mac only and is never sent anywhere.</string>
  <key>NSBluetoothAlwaysUsageDescription</key><string>islet shows your Bluetooth devices in the Connectivity tab.</string>
  <key>NSBluetoothPeripheralUsageDescription</key><string>islet shows your Bluetooth devices in the Connectivity tab.</string>
  <key>NSAppleEventsUsageDescription</key><string>islet reads the current track from Music or Spotify only when the system now-playing information is unavailable. Nothing else is read or sent.</string>
  <key>NSHumanReadableCopyright</key><string>islet</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signing is the development default. For a distributed build, pass
# SIGN_IDENTITY="Developer ID Application: …" and (optionally) NOTARY_PROFILE;
# the DMG step then notarizes and staples the result.
SIGN_ARGS=(--force --sign "$SIGN_IDENTITY")
if [ "$SIGN_IDENTITY" != "-" ]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi
if [ -f "$APP/Contents/Resources/IsletMedia.dylib" ]; then
  codesign "${SIGN_ARGS[@]}" "$APP/Contents/Resources/IsletMedia.dylib"
fi
codesign "${SIGN_ARGS[@]}" "$APP"

if [ "$MAKE_DMG" = "1" ]; then
  DMG="$DMG_DIR/islet-$VERSION.dmg"
  if [ -f "$DMG" ] && [ "$OVERWRITE_DMG" != "1" ]; then
    echo "Refusing to overwrite $DMG; set OVERWRITE_DMG=1 to rebuild it." >&2
    exit 1
  fi

  echo "Building $DMG..."
  rm -rf build/dmg
  mkdir -p build/dmg
  cp -R "$APP" build/dmg/
  ln -s /Applications build/dmg/Applications
  hdiutil create -volname "islet" -srcfolder build/dmg -ov -format UDZO "$DMG"

  if [ "$SIGN_IDENTITY" != "-" ] && [ -n "$NOTARY_PROFILE" ]; then
    echo "Notarizing $DMG..."
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
fi

echo "Built $APP $VERSION ($SIGN_IDENTITY)"
echo "Run: open $PWD/$APP"
if [ "$MAKE_DMG" = "1" ]; then
  echo "DMG: $PWD/$DMG_DIR/islet-$VERSION.dmg"
fi
