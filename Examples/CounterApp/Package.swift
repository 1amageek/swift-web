// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "CounterApp",
    platforms: [
        .macOS("26.2"),
    ],
    products: [
        .library(name: "CounterApp", targets: ["CounterApp"]),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/1amageek/swift-html.git", from: "0.2.2"),
    ],
    targets: [
        .target(
            name: "CounterApp",
            dependencies: [
                .product(name: "SwiftHTML", package: "swift-html"),
                .product(name: "SwiftWeb", package: "swift-web"),
                .product(name: "SwiftWebUI", package: "swift-web"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
