cask "claude-personas" do
  version "0.3.1"
  sha256 "b05a1f6176d000fc01d95b020a853da362e12bfdc01fb647c717a702522940f5"

  url "https://github.com/macfika/claude-personas/releases/download/v#{version}/ClaudePersonas-#{version}.zip"
  name "Claude Personas"
  desc "Run multiple Claude Desktop accounts from the menu bar"
  homepage "https://github.com/macfika/claude-personas"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sequoia

  app "ClaudePersonas.app"

  caveats <<~EOS
    Requires the official Claude Desktop app.
    Updates are managed by Homebrew. Run brew upgrade --cask macfika/claude-personas/claude-personas.
    Account data is preserved when this cask is uninstalled.
  EOS
end
