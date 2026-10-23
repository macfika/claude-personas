#!/bin/bash
# Native regression: only a temporary fixture is launched, never Claude or Claude Personas.
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d "${TMPDIR:-/tmp}/personas-update-exit.XXXXXX")
trap 'rm -rf "$work"' EXIT
app="$work/ExitFixture.app"
mkdir -p "$app/Contents/MacOS"
python3 - "$app" <<'PY'
import pathlib, plistlib, sys, uuid
path = pathlib.Path(sys.argv[1]) / 'Contents/Info.plist'
path.write_bytes(plistlib.dumps({
    'CFBundleIdentifier': 'com.macfika.personas.exit-test.' + uuid.uuid4().hex,
    'CFBundleExecutable': 'ExitFixture', 'CFBundlePackageType': 'APPL', 'LSUIElement': True,
}))
PY
xcrun swiftc tests/UpdateExitFixture.swift -o "$app/Contents/MacOS/ExitFixture"
codesign --sign - "$app"
cp tests/UpdateExitProcessTests.swift "$work/main.swift"
xcrun swiftc Sources/ClaudePersonas/UpdateWatch.swift "$work/main.swift" -o "$work/check"
"$work/check" "$work"
