#!/bin/bash
# Create a stable, per-developer self-signed code-signing identity for the Debug
# ("CloseUp Dev") build.
#
# Why: macOS TCC keys the Accessibility grant on the bundle id + the signing
# identity. An ad-hoc ("-") signature re-hashes on every build, so the grant is
# orphaned and CloseUp Dev must be re-authorised after each `make build` — which
# makes iterating on the Mission Control overlay (which needs Accessibility)
# painful. A *stable* identity keeps the grant across rebuilds.
#
# This is OPT-IN and entirely LOCAL: `make build` works without it (it falls back
# to ad-hoc), and nothing secret is committed — each developer generates their own
# key on their own machine. Safe to re-run: it is a NO-OP if the identity already
# exists, so it never silently rotates the key and invalidates your grant. To
# rotate deliberately, delete it first (`security delete-identity -c '<name>'`).
#
# After running this: `make run`, then grant Accessibility to "CloseUp Dev" in
# System Settings ONE time. The grant then survives every later `make build`.
set -euo pipefail

CN="CloseUp Dev Self-Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -p codesigning | grep -q "$CN"; then
  echo "✓ '$CN' already in your keychain — nothing to do."
  echo "  (To rotate the key, delete it first: security delete-identity -c \"$CN\")"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/ext.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $CN
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# Self-signed cert with the codeSigning EKU + matching private key, bundled as a
# PKCS#12 and imported into the login keychain. Imported with -A (any app may use
# the key without a prompt): without it codesign pops a "wants to access key"
# dialog on every build that "Always Allow" often fails to silence (the macOS
# partition list). This is a throwaway local signing key — it signs nothing of
# value — so allow-all is an acceptable convenience.
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/ext.cnf" >/dev/null 2>&1
# -legacy + SHA1 MAC: OpenSSL 3 otherwise writes a PKCS#12 (AES-256 / SHA-256 MAC)
# that Apple's `security import` rejects with "MAC verification failed"; the legacy
# 3DES/RC2 + SHA1 form is what macOS reads.
openssl pkcs12 -export -legacy -macalg sha1 -name "$CN" \
  -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/id.p12" -passout pass:closeup >/dev/null 2>&1
security import "$TMP/id.p12" -k "$KEYCHAIN" -P closeup -A

if security find-identity -p codesigning | grep -q "$CN"; then
  echo "✓ Created '$CN' in your login keychain."
  echo "  Next:"
  echo "    1) make run"
  echo "    2) Grant Accessibility to \"CloseUp Dev\" in System Settings (once)."
  echo "  The first build may prompt to use the signing key — click \"Always Allow\"."
  echo "  Remove later with: security delete-identity -c \"$CN\""
else
  echo "✗ Import did not yield a usable code-signing identity." >&2
  exit 1
fi
