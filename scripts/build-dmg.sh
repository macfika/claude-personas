#!/bin/bash
# Build a graphical download without changing the signed app or requiring Finder automation.
set -euo pipefail
cd "$(dirname "$0")/.."
app="${1:-$PWD/build/ClaudePersonas.app}"
[[ "$app" = /* ]] || app="$PWD/$app"
[[ -d "$app" ]] || { echo 'Build the app first.' >&2; exit 1; }
codesign --verify --deep --strict "$app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
work=$(mktemp -d "${TMPDIR:-/tmp}/personas-dmg.XXXXXX")
trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1])" "$work"' EXIT
mkdir -p build
xcrun swift scripts/render-dmg-background.swift "$work/background.png"
cp Config/Installation.html "$work/Installation.html"
output="$PWD/build/ClaudePersonas-$version.dmg"
# Python dependencies are build tools only; no new dependency is embedded in the app.
if command -v uv >/dev/null; then
  dmgbuild=(uv tool run --from dmgbuild==1.6.7 dmgbuild)
else
  if [[ ! -x .build/dmg-tools/bin/dmgbuild ]]; then
    python3 -m venv .build/dmg-tools
    .build/dmg-tools/bin/pip install --disable-pip-version-check 'dmgbuild==1.6.7'
  fi
  dmgbuild=(.build/dmg-tools/bin/dmgbuild)
fi
"${dmgbuild[@]}" -s scripts/dmg-settings.py -D "app=$app" -D "background=$work/background.png" \
  -D "instructions=$work/Installation.html" "Claude Personas $version" "$output"
identity="${CODESIGN_IDENTITY:--}"
flags=(--force --sign "$identity")
if [[ "$identity" != - ]]; then flags+=(--timestamp); fi
codesign "${flags[@]}" "$output"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  [[ "$identity" != - ]] || { echo 'Notarization requires CODESIGN_IDENTITY' >&2; exit 1; }
  xcrun notarytool submit "$output" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$output"
  xcrun stapler validate "$output"
fi
codesign --verify --strict "$output"
shasum -a 256 "$output" > build/dmg-sha256.txt
echo "Built $output"
