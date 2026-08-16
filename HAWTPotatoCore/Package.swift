// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HAWTPotatoCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .watchOS(.v11),
        .macOS(.v15)
    ],
    products: [
        .library(name: "HAWTPotatoCore", targets: ["HAWTPotatoCore"])
    ],
    targets: [
        .target(
            name: "HAWTPotatoCore",
            resources: [.process("Resources")]
        )
    ]
)
