#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
app="${PERSONAS_TEST_APP:-$PWD/build/ClaudePersonas.app}"
bin="$app/Contents/MacOS/ClaudePersonas"
[[ -x "$bin" ]] || { echo 'Run ./build.sh --no-install first.' >&2; exit 1; }
test_root=$(mktemp -d "${TMPDIR:-/tmp}/claude-personas-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT
export CLAUDE_PERSONAS_TEST_ROOT="$test_root"
for suite in update version profiles signin launchers signature localization installation; do
  echo "Testing $suite"
  "$bin" "--selftest-$suite"
done
codesign --verify --deep --strict "$app"
architectures=$(lipo -archs "$bin")
for architecture in arm64 x86_64; do
  [[ " $architectures " == *" $architecture "* ]] || { echo "Missing $architecture slice" >&2; exit 1; }
done
echo "Verified architectures: $architectures"
plutil -lint "$app/Contents/Info.plist"

framework="$app/Contents/Frameworks/Sparkle.framework"
[[ -L "$framework/Sparkle" && -L "$framework/Versions/Current" ]] || { echo 'Sparkle framework symlinks were not preserved' >&2; exit 1; }
framework_architectures=$(lipo -archs "$framework/Sparkle")
for architecture in arm64 x86_64; do
  [[ " $framework_architectures " == *" $architecture "* ]] || { echo "Missing Sparkle $architecture slice" >&2; exit 1; }
done
/usr/bin/python3 - "$app" <<'PYVERIFY'
import plistlib
import sys
from pathlib import Path
info = plistlib.loads((Path(sys.argv[1]) / 'Contents/Info.plist').read_bytes())
assert info['SUPublicEDKey'] == info['UpdatePublicKey']
assert info['SUVerifyUpdateBeforeExtraction'] is True
assert info['SUEnableAutomaticChecks'] is True
assert info['SUAutomaticallyUpdate'] is True
assert info['SUFeedURL'] == 'https://github.com/macfika/claude-personas/releases/latest/download/appcast.xml'
PYVERIFY
