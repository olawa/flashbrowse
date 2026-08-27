// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Flashbrowse",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Flashbrowse", targets: ["Flashbrowse"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Flashbrowse",
            dependencies: [],
            path: "Sources"
        )
    ]
)
