#!/usr/bin/env bash
#
# Creates a release keystore and android/key.properties for signing the APK.
# Both files are git-ignored. Keep a secure backup of the keystore: losing it
# means you can never publish an update to the same app identity again.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(dirname "$SCRIPT_DIR")"
ANDROID_DIR="$APP_DIR/android"
KEYSTORE="$ANDROID_DIR/app/release-keystore.jks"
PROPS="$ANDROID_DIR/key.properties"

if [[ -f "$KEYSTORE" || -f "$PROPS" ]]; then
    echo "Refusing to overwrite existing release keystore/key.properties." >&2
    echo "Move them away first if you really want to generate a new identity." >&2
    exit 1
fi

read -rp "Key alias [solver-release]: " ALIAS
ALIAS="${ALIAS:-solver-release}"

read -rsp "Keystore password: " STORE_PASS
echo
read -rsp "Key password (press Enter to reuse the keystore password): " KEY_PASS
echo
KEY_PASS="${KEY_PASS:-$STORE_PASS}"

read -rp "Distinguished name [CN=Solver, OU=Mobile, O=Solver, L=Cairo, C=EG]: " DN
DN="${DN:-CN=Solver, OU=Mobile, O=Solver, L=Cairo, C=EG}"

keytool -genkeypair -v \
    -keystore "$KEYSTORE" \
    -alias "$ALIAS" \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$STORE_PASS" -keypass "$KEY_PASS" \
    -dname "$DN"

chmod 600 "$KEYSTORE"

cat > "$PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=release-keystore.jks
EOF
chmod 600 "$PROPS"

echo
echo "Created: $KEYSTORE"
echo "Created: $PROPS"
echo
echo "Release SHA-1 (add it to the Android OAuth client in Google Cloud):"
keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass "$STORE_PASS" \
    | grep "SHA1:"
echo
echo "Now run: flutter build apk --release"