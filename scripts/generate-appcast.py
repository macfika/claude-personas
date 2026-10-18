#!/usr/bin/env python3
"""Generate Sparkle metadata using the existing legacy Ed25519 seed, via stdin only."""
import base64
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

root = Path(__file__).resolve().parent.parent
os.chdir(root)
archive = Path(sys.argv[1]).resolve()
key = os.environ.get('CLAUDE_PERSONAS_SIGNING_KEY', '').strip()
if len(base64.b64decode(key, validate=True)) != 32:
    raise SystemExit('UPDATE_SIGNING_KEY must contain a base64-encoded 32-byte Ed25519 seed')
sparkle = Path(subprocess.check_output(['./scripts/fetch-sparkle.sh'], text=True).strip())
version = archive.stem.removeprefix('ClaudePersonas-')
namespace = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
with zipfile.ZipFile(archive) as bundle_archive:
    info = plistlib.loads(bundle_archive.read('ClaudePersonas.app/Contents/Info.plist'))
build = int(info['CFBundleVersion'])
if info['CFBundleShortVersionString'] != version:
    raise SystemExit('Archive filename must match its bundle version')
with tempfile.TemporaryDirectory(prefix='personas-appcast-') as temporary:
    directory = Path(temporary)
    shutil.copy2(archive, directory / archive.name)
    # Carry forward existing entries so clients with older OS requirements retain a feed.
    previous = root / 'build/previous-appcast.xml'
    if previous.exists():
        feed = ET.parse(previous)
        previous_versions = [node.text for node in feed.findall('.//sparkle:version', namespace)]
        if any(build <= int(value) for value in previous_versions if value and value.isdigit()):
            raise SystemExit('New CFBundleVersion must be greater than every previous appcast version')
        shutil.copy2(previous, directory / 'appcast.xml')
    subprocess.run([
        str(sparkle / 'bin/generate_appcast'), '--ed-key-file', '-',
        '--download-url-prefix', f'https://github.com/macfika/claude-personas/releases/download/v{version}/',
        '--maximum-deltas', '0', '--link', 'https://github.com/macfika/claude-personas',
        str(directory),
    ], input=key + '\n', text=True, check=True)
    generated = directory / 'appcast.xml'
    feed = ET.parse(generated)
    enclosure = next(node for node in feed.findall('.//enclosure') if node.attrib['url'].endswith(archive.name))
    signature = enclosure.attrib['{'+namespace['sparkle']+'}edSignature']
    # Legacy .zip.sig and Sparkle must be exactly the same Ed25519 signature.
    if signature != Path(str(archive) + '.sig').read_text().strip():
        raise SystemExit('Sparkle signature does not match the legacy update signature')
    subprocess.run([str(sparkle / 'bin/sign_update'), '--ed-key-file', '-', '--verify', str(archive), signature],
                   input=key + '\n', text=True, check=True)
    shutil.copy2(generated, root / 'build/appcast.xml')
print('Generated build/appcast.xml; Sparkle and legacy signatures match')
