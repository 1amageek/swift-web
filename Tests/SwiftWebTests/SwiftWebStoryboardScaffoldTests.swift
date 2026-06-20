@testable import SwiftWebDevelopment
import Foundation
import Testing

@Suite
struct SwiftWebStoryboardScaffoldTests {
    @Test
    func materializesStoryboardPreviewUsingDevelopmentManifestInspection() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebStoryboardScaffoldTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
        let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
        let storyboardPackage = root.appendingPathComponent(".swiftweb/storyboard", isDirectory: true)
        try write(
            """
            // swift-tools-version: 6.3
            import PackageDescription

            let package = Package(
                name: "swift-html",
                products: [
                    .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
                ],
                targets: [
                    .target(name: "SwiftHTML"),
                ]
            )
            """,
            to: swiftHTMLPackage.appendingPathComponent("Package.swift")
        )
        try write(
            """
            // swift-tools-version: 6.3
            import PackageDescription

            let package = Package(
                name: "swift-web",
                products: [
                    .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
                    .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
                    .library(name: "SwiftWebStoryboard", targets: ["SwiftWebStoryboard"]),
                ],
                dependencies: [
                    .package(path: "\(swiftHTMLPackage.path)"),
                ],
                targets: [
                    .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
                    .target(name: "SwiftWebUI"),
                    .target(name: "SwiftWebStoryboard"),
                ]
            )
            """,
            to: swiftWebPackage.appendingPathComponent("Package.swift")
        )
        let catalogSource = swiftWebPackage
            .appendingPathComponent("Sources/SwiftWebStoryboard/Components/CatalogRoot.swift")
        try write("public struct CatalogRoot {}", to: catalogSource)

        try SwiftWebStoryboardScaffold(
            projectDirectory: storyboardPackage,
            swiftWebPackageDirectory: swiftWebPackage
        )
        .materialize(force: false)

        let packageSwift = try String(
            contentsOf: storyboardPackage.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let linkedCatalogSource = storyboardPackage
            .appendingPathComponent("Sources/StoryboardPreview/Components/CatalogRoot.swift")
        let linkedDestination = try FileManager.default.destinationOfSymbolicLink(atPath: linkedCatalogSource.path)

        #expect(
            packageSwift.contains(
                #".package(url: "https://github.com/1amageek/swift-web.git", branch: "main")"#))
        #expect(!packageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
        #expect(packageSwift.contains(".package(path: \"\(swiftHTMLPackage.path)\""))
        #expect(FileManager.default.fileExists(
            atPath: storyboardPackage.appendingPathComponent(".swiftweb-storyboard").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: storyboardPackage.appendingPathComponent("Sources/StoryboardPreview/App.swift").path
        ))
        #expect(
            URL(fileURLWithPath: linkedDestination).resolvingSymlinksInPath()
                == catalogSource.resolvingSymlinksInPath()
        )
    }

    @Test
    func materializesStoryboardPreviewWithReleasedSwiftHTMLWhenLocalCheckoutIsUnavailable() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebStoryboardScaffoldTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
        let storyboardPackage = root.appendingPathComponent(".swiftweb/storyboard", isDirectory: true)
        try write(
            """
            // swift-tools-version: 6.3
            import PackageDescription

            let package = Package(
                name: "swift-web",
                products: [
                    .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
                    .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
                    .library(name: "SwiftWebStoryboard", targets: ["SwiftWebStoryboard"]),
                ],
                targets: [
                    .target(name: "SwiftWeb"),
                    .target(name: "SwiftWebUI"),
                    .target(name: "SwiftWebStoryboard"),
                ]
            )
            """,
            to: swiftWebPackage.appendingPathComponent("Package.swift")
        )
        try write(
            "public struct CatalogRoot {}",
            to: swiftWebPackage
                .appendingPathComponent("Sources/SwiftWebStoryboard/Components/CatalogRoot.swift")
        )

        try SwiftWebStoryboardScaffold(
            projectDirectory: storyboardPackage,
            swiftWebPackageDirectory: swiftWebPackage
        )
        .materialize(force: false)

        let packageSwift = try String(
            contentsOf: storyboardPackage.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )

        #expect(packageSwift.contains(#".package(url: "https://github.com/1amageek/swift-html.git", from: "0.5.0")"#))
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
