cask "claude-personas" do
  version "0.3.2"
  sha256 "4c52c079170420acdae17d164c91b6dfe447352586086a7db2b862df594571cb"

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
