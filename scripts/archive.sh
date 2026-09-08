#!/usr/bin/env bash
set -euo pipefail

: "${SPARKLE_PUBLIC_KEY:?SPARKLE_PUBLIC_KEY is required}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/Export}"
PACKAGE_PATH="${PACKAGE_PATH:-$ROOT_DIR/build/SourcePackages}"
RELEASE_BUILD_NUMBER="${RELEASE_BUILD_NUMBER:-}"

BUILD_NUMBER_ARGS=()
if [[ -n "$RELEASE_BUILD_NUMBER" ]]; then
  if [[ ! "$RELEASE_BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "RELEASE_BUILD_NUMBER must be a positive integer" >&2
    exit 1
  fi
  BUILD_NUMBER_ARGS+=(CURRENT_PROJECT_VERSION="$RELEASE_BUILD_NUMBER")
fi

cd "$ROOT_DIR"
xcodebuild \
  -project MacSweep.xcodeproj \
  -scheme MacSweep \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$PACKAGE_PATH" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  SPARKLE_PUBLIC_KEY="$SPARKLE_PUBLIC_KEY" \
  "${BUILD_NUMBER_ARGS[@]}" \
  build

BUILT_APP="$DERIVED_DATA_PATH/Build/Products/Release/MacSweep.app"
APP_PATH="$EXPORT_PATH/MacSweep.app"
test -d "$BUILT_APP"
mkdir -p "$EXPORT_PATH"
rm -rf "$APP_PATH"
ditto "$BUILT_APP" "$APP_PATH"

APP_INFO_PLIST="$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$APP_INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$APP_INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUEnableAutomaticChecks" "$APP_INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUAllowsAutomaticUpdates" "$APP_INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUAutomaticallyUpdate" "$APP_INFO_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY" "$APP_INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :SUFeedURL string https://github.com/opencorex-org/macsweep/releases/latest/download/appcast.xml" "$APP_INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" "$APP_INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :SUAllowsAutomaticUpdates bool true" "$APP_INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :SUAutomaticallyUpdate bool false" "$APP_INFO_PLIST"

codesign --force --deep --sign - --timestamp=none "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
