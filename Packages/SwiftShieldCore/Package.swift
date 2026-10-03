// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "SwiftShieldCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SwiftShieldCore", targets: ["SwiftShieldCore"])
    ],
    targets: [
        .target(name: "SwiftShieldCore"),
        .testTarget(
            name: "SwiftShieldCoreTests",
            dependencies: ["SwiftShieldCore"]
        )
    ],
    swiftLanguageVersions: [.v5]
)

