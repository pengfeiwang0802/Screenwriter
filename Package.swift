// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Screenwriter",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SWS",
            targets: ["SWS"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SWS",
            path: "Sources/SWS"
        ),
        .executableTarget(
            name: "Screenwriter",
            dependencies: ["SWS"],
            path: "Sources/Screenwriter",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "sws-tool",
            dependencies: ["SWS"],
            path: "Tools/sws-tool"
        )
    ]
)
