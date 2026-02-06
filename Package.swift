// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Ttak",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "ttak",
            path: "Sources/Ttak",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices")
            ]
        )
    ]
)
