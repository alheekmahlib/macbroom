// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacBroom",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MacBroom", targets: ["MacBroom"])
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle.git", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "MacBroom",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/MacBroom",
            exclude: ["Assets/Info.plist"],
            resources: [
                .copy("Assets/AppIcon.png"),
                .copy("Assets/MenuBarIcon.png"),
                .copy("Assets/Logo.png")
            ]
        ),
        .testTarget(
            name: "MacBroomTests",
            dependencies: ["MacBroom"],
            path: "Tests/MacBroomTests"
        )
    ]
)
