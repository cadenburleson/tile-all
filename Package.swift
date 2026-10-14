// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TileAll",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "TileAll", path: "Sources/TileAll")
    ]
)
