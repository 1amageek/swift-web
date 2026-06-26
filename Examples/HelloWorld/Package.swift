// swift-tools-version: 6.3

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
        .package(path: "../.."),
        .package(path: "../../../swift-html"),
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
