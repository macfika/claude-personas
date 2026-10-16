cask "claude-personas" do
  version "0.2.0"
  sha256 "5f370d887887b74edf162deeaba5709f9dbf78c9aab140dd543b7e580545bf30"

  url "https://github.com/macfika/claude-personas/releases/download/v#{version}/ClaudePersonas-#{version}.zip"
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
