// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DisplayColourFilter",
    platforms: [.macOS(.v26)],
    dependencies: [
        // アップデートの確認・ダウンロード・インストール
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0"),
    ],
    targets: [
        // macOS の非公開 API(SkyLight / MediaAccessibility)を呼ぶ C のラッパー
        .target(name: "PrivateDisplayFilter"),
        .executableTarget(
            name: "DisplayColourFilter",
            dependencies: ["PrivateDisplayFilter", .product(name: "Sparkle", package: "Sparkle")],
            // .app に同梱する Contents/Frameworks/Sparkle.framework を読み込めるようにする
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
    ]
)
