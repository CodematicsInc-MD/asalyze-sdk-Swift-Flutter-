#!/usr/bin/env bash
# Refresh the vendored native Swift SDK in this Flutter plugin from the canonical SPM sources.
# The SPM package at ../Sources/Asalyze is the SOURCE OF TRUTH — edit there, then run this to re-vendor.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$here/../Sources/Asalyze"
dest="$here/ios/Classes/native"
rm -rf "$dest"; mkdir -p "$dest"
cp -R "$src/Core" "$src/Networking" "$src/Attribution" "$src/Revenue" "$dest/"
echo "Synced native SDK → ios/Classes/native"
