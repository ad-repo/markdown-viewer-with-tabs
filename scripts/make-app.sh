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

# Resolve the codesigning identity unless the caller forced one. Use the
# SHA-1 hash, since duplicate cert names make codesign refuse the name.
if [ -z "${SIGN_IDENTITY+x}" ]; then
    IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null || true)"
    SIGN_IDENTITY="$(echo "$IDENTITIES" | awk '/"Developer ID Application:/ {print $2; exit}')"
    [ -z "$SIGN_IDENTITY" ] && SIGN_IDENTITY="$(echo "$IDENTITIES" | awk '/"Apple Development:/ {print $2; exit}')"
    if [ -z "$SIGN_IDENTITY" ]; then
        echo "==> No codesigning identity found; falling back to ad-hoc"
        SIGN_IDENTITY="-"
    fi
fi

# Notarization requires hardened runtime plus a secure timestamp; ad-hoc
# signatures can't be timestamped.
TIMESTAMP="--timestamp"
[ "$SIGN_IDENTITY" = "-" ] && TIMESTAMP="--timestamp=none"

echo "==> Signing as: $SIGN_IDENTITY"
codesign --force --options runtime $TIMESTAMP --sign "$SIGN_IDENTITY" "$BUNDLE"
codesign --verify --strict --verbose=2 "$BUNDLE"

echo "==> Done: $BUNDLE"

if [ "${1:-}" = "--run" ]; then
    echo "==> Launching"
    open "$BUNDLE"
fi
