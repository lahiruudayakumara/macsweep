#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/build/Export/MacSweep.app}"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/build/Release/MacSweep.dmg}"

test -d "$APP_PATH"
mkdir -p "$(dirname "$DMG_PATH")"

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

ditto "$APP_PATH" "$STAGING_DIR/MacSweep.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "MacSweep" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
