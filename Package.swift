// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AIUsageWidget",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AIUsageWidget", targets: ["AIUsageWidget"])
    ],
    targets: [
        .executableTarget(
            name: "AIUsageWidget",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
