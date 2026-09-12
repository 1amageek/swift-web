// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-web-storyboard",
    platforms: [.macOS("26.2")],
    products: [
        .library(name: "SwiftWebStoryboard", targets: ["SwiftWebStoryboard"]),
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/1amageek/swift-html.git", from: "0.16.1"),
    ],
    targets: [
        .target(
            name: "SwiftWebStoryboard",
            dependencies: [
                .product(name: "SwiftHTML", package: "swift-html"),
                .product(name: "SwiftWeb", package: "swift-web"),
                .product(name: "SwiftWebStyle", package: "swift-web"),
                .product(name: "SwiftWebUI", package: "swift-web"),
                .product(name: "SwiftWebUIRuntime", package: "swift-web"),
            ],
            exclude: ["DESIGN.md", "INFORMATION_ARCHITECTURE.md", "Catalog/DESIGN.md", "Routes/DESIGN.md"],
            swiftSettings: [.enableUpcomingFeature("ApproachableConcurrency")]
        ),
        .testTarget(
            name: "SwiftWebStoryboardTests",
            dependencies: [
                "SwiftWebStoryboard",
                .product(name: "SwiftHTML", package: "swift-html"),
                .product(name: "SwiftWebStyle", package: "swift-web"),
                .product(name: "SwiftWebUIRuntime", package: "swift-web"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
