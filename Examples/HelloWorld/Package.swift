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
        .package(path: "../.."),
        .package(
            url: "https://github.com/1amageek/swift-html.git",
            revision: "0d2fb652a4ff36d6ad63d91d04db3aee5094986e"
        ),
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
