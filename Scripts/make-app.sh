#!/bin/bash
#
# Assemble EntryLog.app from the SwiftUI executable.
#
# No Xcode involved: SwiftPM builds the binary against the Command
# Line Tools SDK, and the bundle around it is four files and a
# directory layout. The bundle is what carries the Info.plist, and the
# Info.plist is what lets macOS ask for calendar access in this app's
# name rather than the terminal's.

set -euo pipefail

readonly CONFIGURATION="${1:-release}"
readonly PRODUCT="EntryLog"
readonly BUNDLE_ID="com.takahiromori.entrylog"
readonly VERSION="0.1.0"

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP="${ROOT}/build/${PRODUCT}.app"
readonly CONTENTS="${APP}/Contents"

swift build -c "${CONFIGURATION}" --product "${PRODUCT}"

rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"

cp "${ROOT}/.build/${CONFIGURATION}/${PRODUCT}" "${CONTENTS}/MacOS/${PRODUCT}"

# The icon is drawn rather than stored: Scripts/make-icon.swift writes
# every size the iconset wants, and iconutil packs them.
swift "${ROOT}/Scripts/make-icon.swift" "${ROOT}/build/AppIcon.iconset"
iconutil --convert icns \
    --output "${CONTENTS}/Resources/AppIcon.icns" \
    "${ROOT}/build/AppIcon.iconset"

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>                  <string>Entry Log</string>
  <key>CFBundleDisplayName</key>           <string>Entry Log</string>
  <key>CFBundleIdentifier</key>            <string>${BUNDLE_ID}</string>
  <key>CFBundleExecutable</key>            <string>${PRODUCT}</string>
  <key>CFBundlePackageType</key>           <string>APPL</string>
  <key>CFBundleShortVersionString</key>    <string>${VERSION}</string>
  <key>CFBundleVersion</key>               <string>${VERSION}</string>
  <key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
  <key>LSMinimumSystemVersion</key>        <string>14.0</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>NSPrincipalClass</key>              <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>       <true/>
  <key>CFBundleIconFile</key>              <string>AppIcon</string>
  <key>CFBundleIconName</key>              <string>AppIcon</string>

  <key>NSAppleEventsUsageDescription</key>
  <string>Entry Log asks Calendar to open the day an entry falls on, so that you can see it in context. It sends no other commands.</string>

  <key>NSCalendarsFullAccessUsageDescription</key>
  <string>Entry Log lists the calendar entries you wrote down, in the order you wrote them, so it needs to read your calendars. Nothing is changed, and nothing leaves this Mac.</string>
</dict>
</plist>
PLIST

# Ad-hoc, which is all a tool that never leaves this Mac needs. It is
# still required: an unsigned bundle gets a fresh identity on every
# rebuild, and calendar access would have to be granted again each
# time.
codesign --force --sign - --identifier "${BUNDLE_ID}" "${APP}"

echo "built ${APP}"
