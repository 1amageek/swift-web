import Foundation

/// Generates the managed `.swiftweb/storyboard` preview app.
///
/// The catalog UI lives as real, compiled code in swift-web's `SwiftWebStoryboard`
/// target. The scaffold links those sources into the generated app's own target
/// and writes a thin `App` plus manifest. The catalog must appear in the app's
/// own target because the dev runtime discovers client components (for WASM
/// hydration) only under the app's `Sources/<module>/` directory.
struct StoryboardScaffold {
    let projectDirectory: URL
    let swiftWebPackageDirectory: URL

    /// The generated app's module name. It must differ from swift-web's own
    /// `SwiftWebStoryboard` target: the generated package depends on swift-web,
    /// so a shared target name would clash in the package graph.
    static let moduleName = "StoryboardPreview"

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

    func materialize(force: Bool) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: projectDirectory.path) {
            let isManagedDirectory = fileManager.fileExists(atPath: markerFile.path)
            if !force, !isManagedDirectory {
                throw CLIError(
                    message: "storyboard directory already exists and is not managed by swift-web: \(projectDirectory.path)",
                    exitCode: 73
                )
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
            throw CLIError(
                message: "SwiftWebStoryboard catalog sources were not found at \(catalogSourceDirectory.path)",
                exitCode: 66
            )
        }

        let sources = try swiftFiles(in: catalogSourceDirectory, relativePath: "")
        guard !sources.isEmpty else {
            throw CLIError(
                message: "no catalog sources to copy from \(catalogSourceDirectory.path)",
                exitCode: 66
            )
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
        let swiftHTMLPackageDirectory = try resolveSwiftHTMLPackageDirectory()
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
                .package(path: "\(Self.swiftStringLiteral(swiftHTMLPackageDirectory.path))"),
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

    private func resolveSwiftHTMLPackageDirectory() throws -> URL {
        for root in try localPackageRoots(for: swiftWebPackageDirectory) {
            if try packageName(in: root) == "swift-html" {
                return root
            }
        }

        let sibling = swiftWebPackageDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("swift-html", isDirectory: true)
            .standardizedFileURL
        if FileManager.default.fileExists(atPath: sibling.appendingPathComponent("Package.swift").path),
           try packageName(in: sibling) == "swift-html"
        {
            return sibling
        }

        throw CLIError(
            message: "local dependency swift-html was not found from \(swiftWebPackageDirectory.path)",
            exitCode: 66
        )
    }

    private func packageName(in packageDirectory: URL) throws -> String {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        guard FileManager.default.fileExists(atPath: packageFile.path) else {
            throw CLIError(message: "Package.swift was not found in \(packageDirectory.path)", exitCode: 66)
        }

        let manifest = try String(contentsOf: packageFile, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"Package\s*\(\s*name\s*:\s*"([^"]+)""#)
        let range = NSRange(manifest.startIndex..<manifest.endIndex, in: manifest)
        guard let match = regex.firstMatch(in: manifest, range: range),
              match.numberOfRanges > 1,
              let nameRange = Range(match.range(at: 1), in: manifest)
        else {
            throw CLIError(message: "package name was not found in \(packageFile.path)", exitCode: 66)
        }

        return String(manifest[nameRange])
    }

    private func localPackageRoots(for packageDirectory: URL) throws -> [URL] {
        let packageFile = packageDirectory.appendingPathComponent("Package.swift")
        let manifest = try String(contentsOf: packageFile, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"\.package\s*\(\s*path\s*:\s*"([^"]+)""#)
        let range = NSRange(manifest.startIndex..<manifest.endIndex, in: manifest)
        let matches = regex.matches(in: manifest, range: range)
        var roots: [URL] = []
        var seenPaths = Set<String>()

        for match in matches {
            guard match.numberOfRanges > 1,
                  let pathRange = Range(match.range(at: 1), in: manifest)
            else {
                continue
            }

            let rawPath = String(manifest[pathRange])
            let root = rawPath.hasPrefix("/")
                ? URL(fileURLWithPath: rawPath).standardizedFileURL
                : packageDirectory.appendingPathComponent(rawPath, isDirectory: true).standardizedFileURL
            let rootPackageFile = root.appendingPathComponent("Package.swift")
            guard FileManager.default.fileExists(atPath: rootPackageFile.path) else {
                continue
            }

            if seenPaths.insert(root.path).inserted {
                roots.append(root)
            }
        }

        return roots
    }

    private var appSwift: String {
        """
        import SwiftWeb

        public struct \(Self.moduleName): SwiftWeb.App {
            public init() {}

            public var body: some AppContent {
                Redirect("/", to: "/storyboard")
                StoryboardPage()
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
