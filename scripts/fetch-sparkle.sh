#!/bin/bash
# Pinned official universal distribution (also contains the release signing tools).
set -euo pipefail
cd "$(dirname "$0")/.."
version=2.10.0
checksum=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
directory="$PWD/.build/sparkle/$version"
archive="$directory/distribution.tar.xz"
mkdir -p "$directory"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --silent --show-error --retry 3 \
    "https://github.com/sparkle-project/Sparkle/releases/download/$version/Sparkle-$version.tar.xz" -o "$archive.tmp"
  mv "$archive.tmp" "$archive"
fi
actual=$(shasum -a 256 "$archive" | awk '{print $1}')
[[ "$actual" == "$checksum" ]] || { echo 'Sparkle archive checksum mismatch' >&2; exit 1; }
# Re-extract from the verified archive; never trust a stale framework or signing tool.
tar -xf "$archive" -C "$directory"
printf '%s\n' "$directory"
