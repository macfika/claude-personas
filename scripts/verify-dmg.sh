#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
image="$1"
expected="${2:-build/ClaudePersonas.app}"
production="${3:-}"
work=$(mktemp -d "${TMPDIR:-/tmp}/personas-dmg-verify.XXXXXX")
mounted=false
cleanup() {
  if [[ "$mounted" = true ]]; then hdiutil detach "$work/volume" -quiet; fi
  python3 -c 'import shutil,sys; shutil.rmtree(sys.argv[1])' "$work"
}
trap cleanup EXIT
hdiutil verify "$image"
codesign --verify --strict "$image"
if [[ "$production" = --production ]]; then
  codesign --display --verbose=2 "$image" 2>&1 | grep '^Authority=Developer ID Application:' > /dev/null
  xcrun stapler validate "$image"
  spctl --assess --type open --context context:primary-signature --verbose "$image"
fi
hdiutil attach "$image" -readonly -nobrowse -mountpoint "$work/volume" -quiet
mounted=true
[[ "$(readlink "$work/volume/Applications")" = /Applications ]]
[[ -s "$work/volume/.DS_Store" && -f "$work/volume/Installation.html" ]]
[[ -n "$(find "$work/volume" -maxdepth 1 -name '.background*' -print -quit)" ]]
codesign --verify --deep --strict "$work/volume/ClaudePersonas.app"
python3 - "$expected" "$work/volume/ClaudePersonas.app" <<'PYCOMPARE'
import hashlib, os, stat, sys
from pathlib import Path

def manifest(root):
    result = {}
    for base, directories, files in os.walk(root, followlinks=False):
        for name in directories + files:
            path = Path(base) / name
            relative = str(path.relative_to(root))
            if path.is_symlink():
                result[relative] = ('symlink', os.readlink(path))
            elif path.is_file():
                result[relative] = ('file', hashlib.sha256(path.read_bytes()).hexdigest(), stat.S_IMODE(path.stat().st_mode))
            else:
                result[relative] = ('directory',)
    return result
assert manifest(Path(sys.argv[1])) == manifest(Path(sys.argv[2])), 'DMG changed signed application contents or links'
PYCOMPARE
echo 'PASS DMG integrity, Applications link, graphical layout, instructions, and unchanged signed app'
