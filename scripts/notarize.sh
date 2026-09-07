#!/usr/bin/env bash
set -euo pipefail

: "${APPLE_API_KEY_ID:?APPLE_API_KEY_ID is required}"
: "${APPLE_API_ISSUER_ID:?APPLE_API_ISSUER_ID is required}"
: "${APPLE_API_KEY_PATH:?APPLE_API_KEY_PATH is required}"

TARGET_PATH="${1:?Usage: notarize.sh <app-or-dmg-path> [submission-path]}"
SUBMISSION_PATH="${2:-$TARGET_PATH}"

test -e "$TARGET_PATH"
test -f "$SUBMISSION_PATH"

xcrun notarytool submit "$SUBMISSION_PATH" \
  --key-id "$APPLE_API_KEY_ID" \
  --issuer "$APPLE_API_ISSUER_ID" \
  --key "$APPLE_API_KEY_PATH" \
  --wait

xcrun stapler staple "$TARGET_PATH"
xcrun stapler validate "$TARGET_PATH"

if [[ "$TARGET_PATH" == *.app ]]; then
  spctl --assess --type execute --verbose=2 "$TARGET_PATH"
else
  spctl --assess --type open --context context:primary-signature --verbose=2 "$TARGET_PATH"
fi
