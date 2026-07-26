#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "usage: sign-manifest.sh MANIFEST [SIGNATURE]" >&2
  exit 2
fi

manifest=$(realpath "$1")
signature=${2:-"$manifest.sig"}
private_key=${CAMEL_SIGNING_KEY:-"$HOME/.camel-signing/release-ed25519.pem"}
public_key=${CAMEL_PUBLIC_KEY:-"$(dirname "$0")/../keys/release-ed25519.pub.pem"}

[ -s "$manifest" ] || {
  echo "manifest not found: $manifest" >&2
  exit 3
}
[ -s "$private_key" ] || {
  echo "signing key not found: $private_key" >&2
  exit 4
}

openssl pkeyutl -sign -rawin -inkey "$private_key" \
  -in "$manifest" -out "$signature"
openssl pkeyutl -verify -rawin -pubin -inkey "$public_key" \
  -in "$manifest" -sigfile "$signature"

echo "Signed $manifest -> $signature"
