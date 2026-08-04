#!/bin/bash
# One-time: create a stable local code-signing identity so TCC permission
# grants (Accessibility/Mic/Speech) survive rebuilds. Ad-hoc signing
# (`codesign --sign -`) gets a new identity every build, which resets grants.
set -euo pipefail

IDENTITY_NAME="Whisper Dev"
WORKDIR="$(mktemp -d)"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-certificate -c "$IDENTITY_NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "Identity '$IDENTITY_NAME' already exists in login keychain. Nothing to do."
    exit 0
fi

echo "Generating self-signed code-signing certificate '$IDENTITY_NAME'..."
openssl req -x509 -newkey rsa:2048 -days 3650 -keyout "$WORKDIR/dev.key" -out "$WORKDIR/dev.crt" -nodes \
    -subj "/CN=$IDENTITY_NAME" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning"

openssl pkcs12 -export -legacy -in "$WORKDIR/dev.crt" -inkey "$WORKDIR/dev.key" -out "$WORKDIR/dev.p12" -password pass:dev

echo "Importing into login keychain..."
security import "$WORKDIR/dev.p12" -k "$KEYCHAIN" -P dev -T /usr/bin/codesign

echo "Marking certificate trusted for code signing..."
security add-trusted-cert -p codeSign -k "$KEYCHAIN" "$WORKDIR/dev.crt"

rm -rf "$WORKDIR"

echo "Done. If 'codesign' still prompts about an untrusted certificate on first use,"
echo "open Keychain Access, find '$IDENTITY_NAME' under login > My Certificates,"
echo "expand it, and set the 'Code Signing' trust policy to 'Always Trust'."
