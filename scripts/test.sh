#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bin="$PWD/build/ClaudePersonas.app/Contents/MacOS/ClaudePersonas"
[[ -x "$bin" ]] || { echo 'Run ./build.sh --no-install first.' >&2; exit 1; }
test_root=$(mktemp -d "${TMPDIR:-/tmp}/claude-personas-tests.XXXXXX")
trap 'rm -rf "$test_root"' EXIT
export CLAUDE_PERSONAS_TEST_ROOT="$test_root"
for suite in update version profiles signin launchers signature; do
  echo "Testing $suite"
  "$bin" "--selftest-$suite"
done
codesign --verify --deep --strict build/ClaudePersonas.app
lipo "$bin" -verify_arch arm64 x86_64
plutil -lint build/ClaudePersonas.app/Contents/Info.plist
