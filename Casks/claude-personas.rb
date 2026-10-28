cask "claude-personas" do
  version "0.3.3"
  sha256 "d5687e473e8e42a8d9e74ea3430c44bc41e81baee26ee677575de386352da7e9"

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
