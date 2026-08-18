// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "tacho",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "tacho", targets: ["tacho"])
    ],
    targets: [
        .executableTarget(
            name: "tacho",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
