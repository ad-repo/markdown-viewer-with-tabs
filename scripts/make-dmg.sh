#!/bin/bash
#
# Builds a compressed DMG containing the app plus an Applications symlink so
# users can drag the app into /Applications.
#
# Usage: scripts/make-dmg.sh
#
# The app is always rebuilt, then the DMG is signed with the app's Developer
# ID, notarized and stapled. Notarization uses a notarytool keychain profile
# (default "nullplayer"); create it once with:
#
#   xcrun notarytool store-credentials nullplayer \
#       --apple-id you@example.com --team-id Z5ASF6C682
#
# (it prompts for an app-specific password from account.apple.com).
# Set NOTARIZE=0 to skip notarization for a local test build.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="markdown-viewer-with-tabs"
APP="$ROOT/dist/$APP_NAME.app"

NOTARY_PROFILE="${NOTARY_PROFILE:-nullplayer}"
NOTARIZE="${NOTARIZE:-1}"

# Fail before the build if notarization can't work.
if [ "$NOTARIZE" = "1" ] && ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "error: notarytool profile '$NOTARY_PROFILE' missing or invalid. Create it with:" >&2
    echo "  xcrun notarytool store-credentials $NOTARY_PROFILE --apple-id <apple-id> --team-id <team-id>" >&2
    echo "or run with NOTARIZE=0." >&2
    exit 1
fi

# Always rebuild so a stale bundle never ships.
"$ROOT/scripts/make-app.sh"

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

# Sign the DMG with the same identity as the app.
SIG_INFO="$(codesign -dvv "$APP" 2>&1)"
AUTHORITY="$(awk -F= '/^Authority=/ {print $2; exit}' <<<"$SIG_INFO")"
if [ -n "$AUTHORITY" ]; then
    echo "==> Signing DMG as: $AUTHORITY"
    codesign --force --timestamp --sign "$AUTHORITY" "$DMG"
fi

if [ "$NOTARIZE" = "1" ]; then
    case "$AUTHORITY" in
        "Developer ID Application:"*) ;;
        *) echo "error: notarization needs a Developer ID Application signature (got: ${AUTHORITY:-ad-hoc})" >&2; exit 1 ;;
    esac
    echo "==> Notarizing (this can take a few minutes)"
    SUBMIT_OUT="$(xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1)" || true
    echo "$SUBMIT_OUT"
    if ! grep -q "status: Accepted" <<<"$SUBMIT_OUT"; then
        SUBMISSION_ID="$(awk '/^  id:/ {print $2; exit}' <<<"$SUBMIT_OUT")"
        [ -n "$SUBMISSION_ID" ] && xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE"
        echo "error: notarization failed" >&2
        exit 1
    fi
    echo "==> Stapling"
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
    spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi

ls -lh "$DMG"

echo "==> Done: $DMG"
