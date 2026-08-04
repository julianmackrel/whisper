#!/bin/bash
# Double-click this file to set up Whisper after unzipping.
set -e
cd "$(dirname "$0")"

if [ ! -d "Whisper.app" ]; then
    echo "Couldn't find Whisper.app next to this script — make sure both were unzipped together."
    read -p "Press Return to close..."
    exit 1
fi

echo "Setting up Whisper..."
xattr -dr com.apple.quarantine "Whisper.app"

echo "Done. Launching Whisper — look for the mic icon in your menu bar."
open "Whisper.app"

sleep 2
echo ""
echo "You can close this window now."
sleep 3
