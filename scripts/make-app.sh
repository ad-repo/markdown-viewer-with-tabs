#!/bin/bash
#
# Builds the markdown-viewer-with-tabs executable and assembles a
# double-clickable markdown-viewer-with-tabs.app bundle.
#
# Usage: scripts/make-app.sh [--run]
#
# Set SIGN_IDENTITY to pick a codesigning identity (defaults to your
# "Developer ID Application" cert, or Apple Development, whichever exists).
# Set SIGN_IDENTITY="-" to ad-hoc sign instead.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="markdown-viewer-with-tabs"
BUNDLE="$ROOT/dist/$APP_NAME.app"
EXECUTABLE="MarkdownViewer"

echo "==> Building release binary"
swift build -c release --product "$EXECUTABLE"
BIN_PATH="$(swift build -c release --show-bin-path)"

echo "==> Assembling $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"

cp "$BIN_PATH/$EXECUTABLE" "$BUNDLE/Contents/MacOS/$EXECUTABLE"
cp "$ROOT/Resources/Info.plist" "$BUNDLE/Contents/Info.plist"

if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
    cp "$ROOT/Resources/AppIcon.icns" "$BUNDLE/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$BUNDLE/Contents/Info.plist" >/dev/null
fi

# Resolve the codesigning identity unless the caller forced one.
if [ -z "${SIGN_IDENTITY+x}" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | grep -o 'Developer ID Application:[^"]*' \
        | head -n 1 || true)"
    if [ -z "$SIGN_IDENTITY" ]; then
        SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
            | grep -o 'Apple Development:[^"]*' \
            | head -n 1 || true)"
    fi
    if [ -z "$SIGN_IDENTITY" ]; then
        echo "==> No codesigning identity found; falling back to ad-hoc"
        SIGN_IDENTITY="-"
    fi
fi

echo "==> Signing as: $SIGN_IDENTITY"
codesign --force --options runtime --timestamp=none --sign "$SIGN_IDENTITY" "$BUNDLE"
codesign --verify --verbose=2 "$BUNDLE"

echo "==> Done: $BUNDLE"

if [ "${1:-}" = "--run" ]; then
    echo "==> Launching"
    open "$BUNDLE"
fi
