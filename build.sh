#!/bin/bash
# Build a universal, ad-hoc signed app. Installation is always explicit.
set -euo pipefail
cd "$(dirname "$0")"
mode="${1:---no-install}"
case "$mode" in --no-install|--install) ;; *) echo "Usage: $0 [--no-install|--install]" >&2; exit 2 ;; esac
VERSION="${VERSION:-$(cat VERSION)}"
BUILD="${BUILD:-1}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'VERSION must be x.y.z' >&2; exit 2; }
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo 'BUILD must be numeric' >&2; exit 2; }
APP=build/ClaudePersonas.app
mkdir -p build
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do
  xcrun swiftc -swift-version 6 -O -target "$arch-apple-macos15.0" \
    Sources/ClaudePersonas/*.swift -o "build/ClaudePersonas-$arch" -framework AppKit
 done
lipo -create build/ClaudePersonas-arm64 build/ClaudePersonas-x86_64 -output "$APP/Contents/MacOS/ClaudePersonas"
rm build/ClaudePersonas-arm64 build/ClaudePersonas-x86_64
"$APP/Contents/MacOS/ClaudePersonas" --export-iconset build/ClaudePersonas.iconset
iconutil -c icns build/ClaudePersonas.iconset -o "$APP/Contents/Resources/ClaudePersonas.icns"
cp LICENSE NOTICE "$APP/Contents/Resources/"
cp -R Sources/ClaudePersonas/Resources/*.lproj "$APP/Contents/Resources/"
export PERSONAS_BUILD_VERSION="$VERSION" PERSONAS_BUILD_NUMBER="$BUILD"
/usr/bin/python3 - <<'PY'
import os, pathlib, plistlib
key = pathlib.Path('Config/update-public-key.txt').read_text().strip()
info = {
    'CFBundleName': 'Claude Personas', 'CFBundleDisplayName': 'Claude Personas',
    'CFBundleIdentifier': 'com.macfika.claude-personas', 'CFBundleExecutable': 'ClaudePersonas',
    'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': os.environ['PERSONAS_BUILD_VERSION'],
    'CFBundleVersion': os.environ['PERSONAS_BUILD_NUMBER'], 'LSMinimumSystemVersion': '15.0',
    'CFBundleIconFile': 'ClaudePersonas', 'LSUIElement': True,
    'NSHighResolutionCapable': True, 'UpdatePublicKey': key,
    'CFBundleDevelopmentRegion': 'en',
    'CFBundleLocalizations': ['en', 'zh-Hans', 'zh-Hant', 'ja', 'ko'],
    'NSAppleEventsUsageDescription': 'Claude Personas routes Claude sign-in links to the account window that requested them.',
    'CFBundleURLTypes': [
        {'CFBundleURLName': 'Claude sign-in relay', 'CFBundleURLSchemes': ['claude'], 'LSHandlerRank': 'None'},
        {'CFBundleURLName': 'Claude Personas profile apps', 'CFBundleURLSchemes': ['claude-personas']},
    ],
}
with open('build/ClaudePersonas.app/Contents/Info.plist', 'wb') as f:
    plistlib.dump(info, f)
PY
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
rm -f "build/ClaudePersonas-$VERSION.zip"
(cd build && ditto -c -k --norsrc --noextattr --noqtn --keepParent ClaudePersonas.app "ClaudePersonas-$VERSION.zip")
shasum -a 256 "build/ClaudePersonas-$VERSION.zip" > build/sha256.txt
if [[ "$mode" == --install ]]; then
  destination="$HOME/Applications/ClaudePersonas.app"
  if pgrep -x ClaudePersonas >/dev/null; then
    echo 'Quit Claude Personas before installing.' >&2; exit 1
  fi
  mkdir -p "$HOME/Applications"
  rm -rf "$destination"
  ditto "$APP" "$destination"
  open "$destination"
fi
echo "Built build/ClaudePersonas-$VERSION.zip"
