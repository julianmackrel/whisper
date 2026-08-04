#!/bin/bash
# Builds the Whisper executable and assembles/codesigns Whisper.app.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IDENTITY_NAME="Whisper Dev"
APP_DIR="$ROOT_DIR/Whisper.app"

echo "Building release binary..."
cd "$ROOT_DIR"
swift build -c release

BIN_PATH="$ROOT_DIR/.build/release/Whisper"

echo "Assembling app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/Whisper"
cp "$ROOT_DIR/Resources/Info.plist.template" "$APP_DIR/Contents/Info.plist"
if [ -f "$ROOT_DIR/Resources/AppIcon.icns" ]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi

if security find-certificate -c "$IDENTITY_NAME" "$HOME/Library/Keychains/login.keychain-db" >/dev/null 2>&1; then
    echo "Codesigning with '$IDENTITY_NAME'..."
    codesign --force --sign "$IDENTITY_NAME" "$APP_DIR"
else
    echo "No '$IDENTITY_NAME' identity found — run Scripts/make-dev-cert.sh first."
    echo "Falling back to ad-hoc signing (TCC permission grants will NOT persist across rebuilds)."
    codesign --force --sign - "$APP_DIR"
fi

echo "Refreshing Launch Services registration (avoids stale Info.plist caching)..."
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"
"$LSREGISTER" -f "$APP_DIR"

echo "Built $APP_DIR"
