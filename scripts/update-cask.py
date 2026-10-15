#!/usr/bin/env python3
"""Pin the cask to an actual release artifact; never use sha256 :no_check."""
import hashlib
from pathlib import Path
import re
import sys

if len(sys.argv) != 3 or not re.fullmatch(r'\d+\.\d+\.\d+', sys.argv[1]):
    sys.exit('Usage: scripts/update-cask.py VERSION ZIP_PATH')
version, archive = sys.argv[1], Path(sys.argv[2])
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
Path('Casks').mkdir(exist_ok=True)
Path('Casks/claude-personas.rb').write_text(f'''cask "claude-personas" do
  version "{version}"
  sha256 "{checksum}"

  url "https://github.com/macfika/claude-personas/releases/download/v#{{version}}/ClaudePersonas-#{{version}}.zip"
  name "Claude Personas"
  desc "Run multiple Claude Desktop accounts from the menu bar"
  homepage "https://github.com/macfika/claude-personas"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sequoia

  app "ClaudePersonas.app"

  caveats <<~EOS
    Requires the official Claude Desktop app.
    This app is ad-hoc signed and is not notarized by Apple.
    If macOS blocks the first launch, allow it in System Settings > Privacy & Security.
    Account data is preserved when this cask is uninstalled.
  EOS
end
''')
print(f'Cask pinned to {version}: {checksum}')
