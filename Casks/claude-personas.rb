cask "claude-personas" do
  version "0.3.0"
  sha256 "449febd5f6c7b705cb1bee71adf25cdae80e9aa300057960f71418ed69f41d5f"

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
