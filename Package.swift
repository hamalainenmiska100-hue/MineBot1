// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MineBot",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .executable(
            name: "MineBot",
            targets: ["MineBot"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MineBot",
            path: "Sources/MineBot"
        )
    ]
)
