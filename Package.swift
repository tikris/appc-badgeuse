// swift-tools-version:5.9
// Paquet utilisé uniquement par la CI pour tester la signature des pass sur macOS.
// L'application elle-même se construit avec le projet Xcode (voir README).
import PackageDescription

let package = Package(
    name: "BadgeCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "BadgeCore", path: "App/BadgeCreche/Core"),
        .testTarget(
            name: "BadgeCoreTests",
            dependencies: ["BadgeCore"],
            path: "Tests/BadgeCoreTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
