// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DisplayColourFilter",
    platforms: [.macOS(.v26)],
    targets: [
        // macOS の非公開 API(SkyLight / MediaAccessibility)を呼ぶ C のラッパー
        .target(name: "PrivateDisplayFilter"),
        .executableTarget(name: "DisplayColourFilter", dependencies: ["PrivateDisplayFilter"]),
    ]
)
