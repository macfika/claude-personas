#!/bin/bash
# A real Sparkle replace-and-relaunch test, isolated from installed applications.
# Requires an interactive macOS login session. All fixture apps and keys are temporary.
set -euo pipefail
cd "$(dirname "$0")/.."
export PERSONAS_SPARKLE_TEST_ROOT="$PWD"
export PERSONAS_SPARKLE_TEST_DISTRIBUTION="$(./scripts/fetch-sparkle.sh)"
python3 - <<'PY'
import base64
from functools import partial
import http.server
import json
import os
from pathlib import Path
import plistlib
import shutil
import signal
import subprocess
import tempfile
import threading
import time
import uuid

root = Path(os.environ['PERSONAS_SPARKLE_TEST_ROOT'])
sparkle = Path(os.environ['PERSONAS_SPARKLE_TEST_DISTRIBUTION'])
bundle_id = 'com.macfika.claude-personas.sparkle-fixture.' + uuid.uuid4().hex
process = None
server = None
with tempfile.TemporaryDirectory(prefix='personas-sparkle-update-', dir='/private/tmp') as temporary:
    work = Path(temporary)
    try:
        feed = work / 'feed'; feed.mkdir()
        handler = partial(http.server.SimpleHTTPRequestHandler, directory=str(feed))
        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        feed_url = f'http://127.0.0.1:{server.server_port}/'
        # This throwaway test key never reads or writes the login Keychain.
        seed = os.urandom(32)
        key = base64.b64encode(seed).decode()
        public_der = subprocess.check_output(['openssl', 'pkey', '-inform', 'DER', '-pubout', '-outform', 'DER'],
            input=bytes.fromhex('302e020100300506032b657004220420') + seed)
        public = base64.b64encode(public_der[-32:]).decode()
        executable = work / 'Fixture'
        subprocess.run(['xcrun', 'clang', '-fobjc-arc', '-Wno-incompatible-pointer-types',
            '-framework', 'Cocoa', '-F', str(sparkle), '-framework', 'Sparkle',
            '-Wl,-rpath,@executable_path/../Frameworks', str(root / 'tests/SparkleUpdateFixture.m'),
            '-o', str(executable)], check=True)
        app_name = 'SparkleFixture.app'
        installed = work / 'installed' / app_name
        updated = work / 'payload' / app_name
        marker = work / 'relaunch.json'
        events = work / 'events.log'
        def make_app(app, version):
            (app / 'Contents/MacOS').mkdir(parents=True)
            (app / 'Contents/Frameworks').mkdir()
            shutil.copy2(executable, app / 'Contents/MacOS/Fixture')
            framework = app / 'Contents/Frameworks/Sparkle.framework'
            subprocess.run(['ditto', str(sparkle / 'Sparkle.framework'), str(framework)], check=True)
            info = dict(CFBundleIdentifier=bundle_id, CFBundleName='Sparkle Fixture', CFBundleExecutable='Fixture',
                CFBundlePackageType='APPL', CFBundleVersion=str(version), CFBundleShortVersionString=f'1.{version}',
                LSUIElement=True, LSMinimumSystemVersion='15.0', SUFeedURL=feed_url + 'appcast.xml',
                SUPublicEDKey=public, SUEnableAutomaticChecks=False, SUAutomaticallyUpdate=False,
                SUVerifyUpdateBeforeExtraction=True, FixtureMarkerPath=str(marker), FixtureLogPath=str(events),
                NSAppTransportSecurity={'NSAllowsLocalNetworking': True, 'NSAllowsArbitraryLoads': True})
            (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
            helpers = list((framework / 'Versions/B/XPCServices').glob('*.xpc'))
            helpers += [framework / 'Versions/B/Updater.app', framework / 'Versions/B/Autoupdate', framework, app]
            for path in helpers:
                subprocess.run(['codesign', '--force', '--sign', '-', '--preserve-metadata=entitlements', str(path)], check=True,
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        make_app(installed, 1)
        make_app(updated, 2)
        archive = feed / 'SparkleFixture-2.zip'
        subprocess.run(['ditto', '-c', '-k', '--keepParent', str(updated), str(archive)], check=True)
        subprocess.run([str(sparkle / 'bin/generate_appcast'), '--ed-key-file', '-', '--download-url-prefix', feed_url,
            '--maximum-deltas', '0', str(feed)], input=key + '\n', text=True, check=True)
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(installed)], check=True)
        # Launch the executable from its temporary .app. Sparkle relaunches via LaunchServices itself.
        process = subprocess.Popen([str(installed / 'Contents/MacOS/Fixture')],
            stdout=(work / 'stdout.log').open('w'), stderr=(work / 'stderr.log').open('w'))
        deadline = time.monotonic() + 90
        while not marker.exists() and time.monotonic() < deadline:
            time.sleep(0.25)
        if not marker.exists():
            for path in (events, work / 'stderr.log'):
                if path.exists(): print(path.read_text())
            raise SystemExit('FAIL: Sparkle did not replace and relaunch the fixture within 90 seconds')
        result = json.loads(marker.read_text())
        assert result['version'] == '2'
        assert result['pid'] != process.pid, 'Relaunch must create a new process'
        assert Path(result['bundlePath']).resolve() == installed.resolve(), 'New app must launch from original install path'
        process.wait(timeout=10)
        info = plistlib.loads((installed / 'Contents/Info.plist').read_bytes())
        assert info['CFBundleVersion'] == '2', 'On-disk bundle was not replaced'
        log = events.read_text()
        assert f'terminating pid={process.pid} version=1' in log, 'Old application did not report termination'
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(installed)], check=True)
        print(log)
        print('PASS: real Sparkle download, Ed25519 validation, extraction, old-app quit, bundle replacement and new-app relaunch')
        print('Only isolated temporary ad-hoc-signed fixtures were used; this is not a notarization test.')
    finally:
        if process and process.poll() is None:
            process.terminate()
            try: process.wait(timeout=5)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
        if server: server.shutdown(); server.server_close()
        # Remove only this unique fixture's preferences/cache (never a production bundle identifier).
        subprocess.run(['defaults', 'delete', bundle_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for directory in (Path.home() / 'Library/Caches' / bundle_id, Path.home() / 'Library/Application Support' / bundle_id):
            if directory.exists(): shutil.rmtree(directory)
PY
