#!/bin/bash
# Import the Developer ID Application certificate into a temporary keychain for
# CI signing. Reads base64 + password from the environment.
#
#   MACOS_CERTIFICATE       base64 of the .p12
#   MACOS_CERTIFICATE_PWD   password for the .p12
#
# Leaves a keychain that codesign can use for the rest of the job.
set -euo pipefail

: "${MACOS_CERTIFICATE:?missing}"
: "${MACOS_CERTIFICATE_PWD:?missing}"

KEYCHAIN="$RUNNER_TEMP/closeup-signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 24)"
CERT_PATH="$RUNNER_TEMP/certificate.p12"

echo -n "$MACOS_CERTIFICATE" | base64 --decode -o "$CERT_PATH"

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"

security import "$CERT_PATH" -P "$MACOS_CERTIFICATE_PWD" \
	-A -t cert -f pkcs12 -k "$KEYCHAIN"

# Allow codesign to use the signing key without an interactive prompt.
security set-key-partition-list -S apple-tool:,apple:,codesign: \
	-s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null

# Put our keychain first in the user search list while PRESERVING the keychains
# already there (login.keychain-db et al.) — replacing the list wholesale can
# strip a keychain a later step relies on.
security list-keychain -d user -s "$KEYCHAIN" $(security list-keychains -d user | xargs)

rm -f "$CERT_PATH"
echo "Imported Developer ID certificate into $KEYCHAIN"
