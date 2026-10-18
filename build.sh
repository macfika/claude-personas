#!/bin/bash
# Build a universal app. Set CODESIGN_IDENTITY and NOTARY_PROFILE for distribution.
set -euo pipefail
cd "$(dirname "$0")"
mode="${1:---no-install}"
case "$mode" in --no-install|--install) ;; *) echo "Usage: $0 [--no-install|--install]" >&2; exit 2 ;; esac
VERSION="${VERSION:-$(cat VERSION)}"
# Version ordering is independent of workflow run counts (including re-created workflows).
version_build=$(/usr/bin/python3 - "$VERSION" <<'PYBUILD'
import sys
parts = sys.argv[1].split('.')
if len(parts) != 3 or any(not part.isdigit() for part in parts):
    raise SystemExit('VERSION must be x.y.z')
major, minor, patch = map(int, parts)
if minor >= 10000 or patch >= 10000:
    raise SystemExit('Minor and patch versions must be below 10000')
print(major * 100000000 + minor * 10000 + patch)
PYBUILD
)
BUILD="${BUILD:-$version_build}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
SPARKLE_ROOT=$(./scripts/fetch-sparkle.sh)
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'VERSION must be x.y.z' >&2; exit 2; }
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo 'BUILD must be numeric' >&2; exit 2; }
APP=build/ClaudePersonas.app
mkdir -p build
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
ditto "$SPARKLE_ROOT/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
for arch in arm64 x86_64; do
  xcrun swiftc -swift-version 6 -O -target "$arch-apple-macos15.0" \
    Sources/ClaudePersonas/*.swift -o "build/ClaudePersonas-$arch" -framework AppKit \
    -F "$SPARKLE_ROOT" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks
 done
lipo -create build/ClaudePersonas-arm64 build/ClaudePersonas-x86_64 -output "$APP/Contents/MacOS/ClaudePersonas"
rm build/ClaudePersonas-arm64 build/ClaudePersonas-x86_64
"$APP/Contents/MacOS/ClaudePersonas" --export-iconset build/ClaudePersonas.iconset
iconutil -c icns build/ClaudePersonas.iconset -o "$APP/Contents/Resources/ClaudePersonas.icns"
cp LICENSE NOTICE "$APP/Contents/Resources/"
cp "$SPARKLE_ROOT/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE"
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
    'SUFeedURL': 'https://github.com/macfika/claude-personas/releases/latest/download/appcast.xml',
    'SUPublicEDKey': key, 'SUEnableAutomaticChecks': True,
    'SUAutomaticallyUpdate': True, 'SUVerifyUpdateBeforeExtraction': True,
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
# Sign inside-out; --deep is only used for verification, never for signing.
# Preserve Sparkle helper entitlements when replacing the upstream signatures.
sign_flags=(--force --sign "$CODESIGN_IDENTITY" --preserve-metadata=entitlements)
if [[ "$CODESIGN_IDENTITY" != - ]]; then
  sign_flags+=(--options runtime --timestamp)
fi
framework="$APP/Contents/Frameworks/Sparkle.framework"
for helper in "$framework"/Versions/B/XPCServices/*.xpc "$framework/Versions/B/Updater.app" "$framework/Versions/B/Autoupdate"; do
  codesign "${sign_flags[@]}" "$helper"
done
codesign "${sign_flags[@]}" "$framework"
codesign "${sign_flags[@]}" "$APP"
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  [[ "$CODESIGN_IDENTITY" != - ]] || { echo 'Notarization requires CODESIGN_IDENTITY' >&2; exit 1; }
  ditto -c -k --keepParent "$APP" build/notarization.zip
  xcrun notarytool submit build/notarization.zip --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  rm build/notarization.zip
fi
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
