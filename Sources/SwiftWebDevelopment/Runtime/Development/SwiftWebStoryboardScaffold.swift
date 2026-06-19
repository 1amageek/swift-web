import Foundation

public enum SwiftWebStoryboardScaffoldError: Error, Sendable, CustomStringConvertible {
    case unmanagedDirectory(URL)
    case catalogSourcesNotFound(URL)
    case emptyCatalogSources(URL)

    public var exitCode: Int {
        switch self {
        case .unmanagedDirectory:
            73
        case .catalogSourcesNotFound, .emptyCatalogSources:
            66
        }
    }

    public var description: String {
        switch self {
        case .unmanagedDirectory(let directory):
            "storyboard directory already exists and is not managed by swift-web: \(directory.path)"
        case .catalogSourcesNotFound(let directory):
            "SwiftWebStoryboard catalog sources were not found at \(directory.path)"
        case .emptyCatalogSources(let directory):
            "no catalog sources to copy from \(directory.path)"
        }
    }
}

/// Generates the managed `.swiftweb/storyboard` preview app.
///
/// The catalog UI lives as real, compiled code in swift-web's `SwiftWebStoryboard`
/// target. The scaffold links those sources into the generated app's own target
/// and writes a thin `App` plus manifest. The catalog must appear in the app's
/// own target because the dev runtime discovers client components (for WASM
/// hydration) only under the app's `Sources/<module>/` directory.
public struct SwiftWebStoryboardScaffold: Sendable {
    public let projectDirectory: URL
    public let swiftWebPackageDirectory: URL

    /// The generated app's module name. It must differ from swift-web's own
    /// `SwiftWebStoryboard` target: the generated package depends on swift-web,
    /// so a shared target name would clash in the package graph.
    public static let moduleName = "StoryboardPreview"

    public init(projectDirectory: URL, swiftWebPackageDirectory: URL) {
        self.projectDirectory = projectDirectory
        self.swiftWebPackageDirectory = swiftWebPackageDirectory
    }

    private var markerFile: URL {
        projectDirectory.appendingPathComponent(".swiftweb-storyboard")
    }

    private var catalogSourceDirectory: URL {
        swiftWebPackageDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("SwiftWebStoryboard", isDirectory: true)
    }

    private var moduleSourceDirectory: URL {
        projectDirectory
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent(Self.moduleName, isDirectory: true)
    }

    public func materialize(force: Bool) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: projectDirectory.path) {
            let isManagedDirectory = fileManager.fileExists(atPath: markerFile.path)
            if !force, !isManagedDirectory {
                throw SwiftWebStoryboardScaffoldError.unmanagedDirectory(projectDirectory)
            }
            if force {
                try fileManager.removeItem(at: projectDirectory)
            } else if isManagedDirectory {
                try removeOwnedGeneratedFiles()
            }
        }

        try fileManager.createDirectory(at: projectDirectory, withIntermediateDirectories: true)
        try writeText("managed by swift-web\n", to: ".swiftweb-storyboard")
        try writeText(packageSwift(), to: "Package.swift")
        try writeText(readme, to: "README.md")
        try writeText(appSwift, to: "Sources/\(Self.moduleName)/App.swift")
        try linkCatalogSources()
    }

    private func removeOwnedGeneratedFiles() throws {
        let fileManager = FileManager.default
        for path in ["Package.swift", "README.md", "Sources"] {
            let url = projectDirectory.appendingPathComponent(path)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    /// Links every `.swift` file from swift-web's `SwiftWebStoryboard` target
    /// into the generated app's module, preserving the relative directory layout.
    private func linkCatalogSources() throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: catalogSourceDirectory.path) else {
            throw SwiftWebStoryboardScaffoldError.catalogSourcesNotFound(catalogSourceDirectory)
        }

        let sources = try swiftFiles(in: catalogSourceDirectory, relativePath: "")
        guard !sources.isEmpty else {
            throw SwiftWebStoryboardScaffoldError.emptyCatalogSources(catalogSourceDirectory)
        }

        for source in sources {
            let destination = moduleSourceDirectory.appendingPathComponent(source.relativePath)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.createSymbolicLink(at: destination, withDestinationURL: source.url)
        }
    }

    private func swiftFiles(
        in directory: URL,
        relativePath: String
    ) throws -> [(url: URL, relativePath: String)] {
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var files: [(url: URL, relativePath: String)] = []
        for child in children {
            let childRelativePath = relativePath.isEmpty
                ? child.lastPathComponent
                : "\(relativePath)/\(child.lastPathComponent)"
            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                files.append(contentsOf: try swiftFiles(in: child, relativePath: childRelativePath))
            } else if child.pathExtension == "swift" {
                files.append((child, childRelativePath))
            }
        }
        return files
    }

    private func writeText(_ contents: String, to relativePath: String) throws {
        let url = projectDirectory.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func packageSwift() throws -> String {
        let swiftHTMLDependency = try swiftHTMLDependencyDeclaration()
        return """
        // swift-tools-version: 6.3

        import PackageDescription

        let package = Package(
            name: "\(Self.moduleName)",
            platforms: [
                .macOS("26.2"),
            ],
            products: [
                .library(name: "\(Self.moduleName)", targets: ["\(Self.moduleName)"]),
            ],
            dependencies: [
                .package(path: "\(Self.swiftStringLiteral(swiftWebPackageDirectory.path))"),
                \(swiftHTMLDependency),
            ],
            targets: [
                .target(
                    name: "\(Self.moduleName)",
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
        """
    }

    private func swiftHTMLDependencyDeclaration() throws -> String {
        if let directory = try localSwiftHTMLPackageDirectory() {
            return #".package(path: "\#(Self.swiftStringLiteral(directory.path))")"#
        }

        return #".package(url: "https://github.com/1amageek/swift-html.git", from: "0.5.0")"#
    }

    private func localSwiftHTMLPackageDirectory() throws -> URL? {
        if let root = try SwiftWebPackageManifestInspector.optionalLocalDependencyRoot(
            named: "swift-html",
            in: swiftWebPackageDirectory
        ) {
            return root
        }

        let sibling = swiftWebPackageDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("swift-html", isDirectory: true)
            .standardizedFileURL
        if FileManager.default.fileExists(atPath: sibling.appendingPathComponent("Package.swift").path),
           try SwiftWebPackageManifestInspector.packageName(in: sibling) == "swift-html"
        {
            return sibling
        }

        return nil
    }

    private var appSwift: String {
        """
        import SwiftWeb

        public struct \(Self.moduleName): SwiftWeb.App {
            public init() {}

            public var body: some AppContent {
                Redirect("/", to: "/storyboard")
                StoryboardPage()
                StoryboardSelectionPage()
            }
        }
        """
    }

    private var readme: String {
        """
        # SwiftWeb Storyboard

        This package is generated by `swift-web storyboard`.

        It hosts the SwiftWebUI component storyboard for inspecting component styles
        across themes and style systems. The catalog itself lives in swift-web's
        `SwiftWebStoryboard` target; this package is a thin app that links those
        sources so the dev runtime can build the client WASM runtime. The app source
        package is not modified.

        ```bash
        swift-web storyboard --package-path \(Self.shellPath(projectDirectory.deletingLastPathComponent().deletingLastPathComponent().path))
        ```
        """
    }

    private static func swiftStringLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private static func shellPath(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
