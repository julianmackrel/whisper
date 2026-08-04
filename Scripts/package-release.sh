#!/bin/bash
# Builds Whisper.app and packages it with Install.command into a release zip
# (Whisper-release.zip) — what actually gets attached to a GitHub Release.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGING_DIR="$ROOT_DIR/.release-staging/Whisper"
ZIP_PATH="$ROOT_DIR/Whisper-release.zip"

"$ROOT_DIR/Scripts/bundle-app.sh"

echo "Assembling release folder..."
rm -rf "$ROOT_DIR/.release-staging" "$ZIP_PATH"
mkdir -p "$STAGING_DIR"
cp -R "$ROOT_DIR/Whisper.app" "$STAGING_DIR/Whisper.app"
cp "$ROOT_DIR/Resources/Install.command" "$STAGING_DIR/Install.command"
chmod +x "$STAGING_DIR/Install.command"

echo "Zipping..."
ditto -c -k --keepParent "$STAGING_DIR" "$ZIP_PATH"
rm -rf "$ROOT_DIR/.release-staging"

echo "Built $ZIP_PATH"
