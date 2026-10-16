// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudePersonas",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "ClaudePersonas", targets: ["ClaudePersonas"])],
    targets: [.executableTarget(name: "ClaudePersonas", resources: [.process("Resources")])],
    swiftLanguageModes: [.v6]
)
