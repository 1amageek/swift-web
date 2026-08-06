// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "HelloWorld",
    platforms: [
        .macOS("26.2"),
    ],
    products: [
        .library(name: "HelloWorld", targets: ["HelloWorld"]),
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/swift-web.git", from: "0.10.0"),
        .package(url: "https://github.com/1amageek/swift-html.git", from: "0.14.0"),
    ],
    targets: [
        .target(
            name: "HelloWorld",
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
