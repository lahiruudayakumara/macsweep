#!/usr/bin/env bash
set -euo pipefail

# MacSweep Installer
# Copies MacSweep.app to /Applications and removes the quarantine attribute
# so it opens without the "Apple could not verify" Gatekeeper warning.

APP_NAME="MacSweep.app"
INSTALL_DIR="/Applications"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Look for the app in common locations
if [[ -d "$SCRIPT_DIR/../$APP_NAME" ]]; then
  SOURCE="$SCRIPT_DIR/../$APP_NAME"
elif [[ -d "$SCRIPT_DIR/$APP_NAME" ]]; then
  SOURCE="$SCRIPT_DIR/$APP_NAME"
elif [[ -d "$SCRIPT_DIR/../build/Export/$APP_NAME" ]]; then
  SOURCE="$SCRIPT_DIR/../build/Export/$APP_NAME"
else
  echo "Error: Could not find $APP_NAME" >&2
  echo "Place this script next to $APP_NAME and try again." >&2
  exit 1
fi

echo "Installing MacSweep..."
echo "  From: $SOURCE"
echo "  To:   $INSTALL_DIR/$APP_NAME"

# Copy app to /Applications
rm -rf "$INSTALL_DIR/$APP_NAME"
cp -R "$SOURCE" "$INSTALL_DIR/$APP_NAME"

# Remove quarantine attribute to bypass Gatekeeper
xattr -cr "$INSTALL_DIR/$APP_NAME"

echo ""
echo "✅ MacSweep installed successfully!"
echo "   You can now open it from Applications."
