#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$PROJECT_DIR/build/export/AntiAway.app}"
OUTPUT_PATH="${2:-$PROJECT_DIR/build/AntiAway.dmg}"
STAGING_DIR="$PROJECT_DIR/build/dmg-root"
VOLUME_NAME="AntiAway"
# Use the current certificate fingerprint because the Keychain can contain
# multiple Developer ID certificates with the same display name.
SIGNING_IDENTITY="${SIGNING_IDENTITY:-39C1289D210FF66130BAE6D3C76BC5A0691367F3}"

if [[ ! -d "$APP_PATH" ]]; then
  print -u2 "error: app not found at $APP_PATH"
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  print -u2 "error: hdiutil is required"
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/AntiAway.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$OUTPUT_PATH"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_PATH"

codesign --force \
  --sign "$SIGNING_IDENTITY" \
  --timestamp \
  "$OUTPUT_PATH"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$OUTPUT_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
  xcrun stapler staple "$OUTPUT_PATH"
  xcrun stapler validate "$OUTPUT_PATH"
else
  print "Created unsigned-for-notarization DMG: $OUTPUT_PATH"
  print "Set NOTARY_PROFILE to submit and staple it automatically."
fi
