// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudePersonas",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "ClaudePersonas", targets: ["ClaudePersonas"])],
    targets: [.executableTarget(name: "ClaudePersonas")],
    swiftLanguageModes: [.v6]
)
