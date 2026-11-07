#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Islet.app"
VERSION="${VERSION:-0.3.0}"
BUILD="${BUILD:-1}"
# ARCHS="arm64 x86_64" produces a universal binary.
ARCHS="${ARCHS:-$(uname -m)}"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

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
    -o "build/Islet-$arch"
  SLICES+=("build/Islet-$arch")
done

if [ "${#SLICES[@]}" -gt 1 ]; then
  lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/Islet"
else
  cp "${SLICES[0]}" "$APP/Contents/MacOS/Islet"
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
  codesign --force --sign - "$APP/Contents/Resources/IsletMedia.dylib" 2>/dev/null || true
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.dhanuz.islet</string>
  <key>CFBundleName</key><string>Islet</string>
  <key>CFBundleDisplayName</key><string>Islet</string>
  <key>CFBundleExecutable</key><string>Islet</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>Islet shows today's events in the notch. Your calendar is read on this Mac only and is never sent anywhere.</string>
  <key>NSCalendarsUsageDescription</key><string>Islet shows today's events in the notch. Your calendar is read on this Mac only and is never sent anywhere.</string>
  <key>NSAppleEventsUsageDescription</key><string>Islet reads the current track from Music or Spotify only when the system now-playing information is unavailable. Nothing else is read or sent.</string>
  <key>NSHumanReadableCopyright</key><string>Islet</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "Built $APP $VERSION"
echo "Run: open $PWD/$APP"
