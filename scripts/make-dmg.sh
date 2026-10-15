#!/bin/bash
#
# Builds a compressed DMG containing the app plus an Applications symlink so
# users can drag the app into /Applications.
#
# Usage: scripts/make-dmg.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="markdown-viewer-with-tabs"
APP="$ROOT/dist/$APP_NAME.app"

if [ ! -d "$APP" ]; then
    echo "==> App bundle not found; building it first"
    "$ROOT/scripts/make-app.sh"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/dist/$APP_NAME-$VERSION.dmg"
STAGING="$ROOT/dist/dmg-staging"

echo "==> Preparing DMG staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

echo "==> Creating $DMG"
rm -f "$DMG"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG" >/dev/null

echo "==> Verifying"
hdiutil verify "$DMG" >/dev/null
ls -lh "$DMG"

echo "==> Done: $DMG"
