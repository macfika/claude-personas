// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudePersonas",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "ClaudePersonas", targets: ["ClaudePersonas"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [.executableTarget(name: "ClaudePersonas",
        dependencies: [.product(name: "Sparkle", package: "Sparkle")],
        resources: [.process("Resources")])],
    swiftLanguageModes: [.v6]
)
