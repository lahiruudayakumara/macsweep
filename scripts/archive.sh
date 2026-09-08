#!/usr/bin/env bash
set -euo pipefail

: "${DEVELOPMENT_TEAM:?DEVELOPMENT_TEAM is required}"
: "${SPARKLE_PUBLIC_KEY:?SPARKLE_PUBLIC_KEY is required}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/MacSweep.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/Export}"
PACKAGE_PATH="${PACKAGE_PATH:-$ROOT_DIR/build/SourcePackages}"

cd "$ROOT_DIR"
xcodebuild \
  -project MacSweep.xcodeproj \
  -scheme MacSweep \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -clonedSourcePackagesDirPath "$PACKAGE_PATH" \
  DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  SPARKLE_PUBLIC_KEY="$SPARKLE_PUBLIC_KEY" \
  archive

xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist Distribution/ExportOptions/DeveloperIDExportOptions.plist

test -d "$EXPORT_PATH/MacSweep.app"
codesign --verify --deep --strict --verbose=2 "$EXPORT_PATH/MacSweep.app"
