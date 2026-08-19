#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?usage: generate_appcast.sh VERSION DMG_PATH [RELEASE_NOTES_PATH]}"
DMG_PATH="${2:?usage: generate_appcast.sh VERSION DMG_PATH [RELEASE_NOTES_PATH]}"
RELEASE_NOTES_PATH="${3:-}"
UPDATES_DIR="$PROJECT_DIR/build/sparkle-updates"
ARCHIVE_NAME="AntiAway-$VERSION.dmg"
DOWNLOAD_URL_PREFIX="https://github.com/Andrescmm/anti-away/releases/download/v$VERSION/"

if [[ ! -f "$DMG_PATH" ]]; then
  print -u2 "error: DMG not found at $DMG_PATH"
  exit 1
fi

SPARKLE_TOOL="${SPARKLE_GENERATE_APPCAST:-}"
if [[ -z "$SPARKLE_TOOL" ]]; then
  SPARKLE_TOOL="$(find "$HOME/Library/Developer/Xcode/DerivedData" \
    -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast' \
    -type f -print -quit)"
fi

if [[ -z "$SPARKLE_TOOL" || ! -x "$SPARKLE_TOOL" ]]; then
  print -u2 "error: Sparkle generate_appcast was not found. Resolve packages in Xcode first."
  exit 1
fi

mkdir -p "$UPDATES_DIR"
cp "$DMG_PATH" "$UPDATES_DIR/$ARCHIVE_NAME"

if [[ -f "$PROJECT_DIR/appcast.xml" ]]; then
  cp "$PROJECT_DIR/appcast.xml" "$UPDATES_DIR/appcast.xml"
fi

if [[ -n "$RELEASE_NOTES_PATH" ]]; then
  if [[ ! -f "$RELEASE_NOTES_PATH" ]]; then
    print -u2 "error: release notes not found at $RELEASE_NOTES_PATH"
    exit 1
  fi
  cp "$RELEASE_NOTES_PATH" "$UPDATES_DIR/AntiAway-$VERSION.md"
fi

"$SPARKLE_TOOL" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --link "https://github.com/Andrescmm/anti-away" \
  --maximum-versions 5 \
  -o appcast.xml \
  "$UPDATES_DIR"

cp "$UPDATES_DIR/appcast.xml" "$PROJECT_DIR/appcast.xml"

print "Generated signed update metadata:"
print "  Archive: $UPDATES_DIR/$ARCHIVE_NAME"
print "  Feed:    $PROJECT_DIR/appcast.xml"
print ""
print "Upload the versioned archive to GitHub release v$VERSION, then commit appcast.xml."
