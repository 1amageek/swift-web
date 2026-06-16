import Foundation
import SwiftWeb

struct NewCommand {
    let appName: String
    let outputDirectory: URL
    let template: AppTemplate
    let force: Bool

    static func parse(_ parser: ArgumentParser) throws -> NewCommand {
        var parser = parser
        guard let appName = parser.next(), !appName.hasPrefix("--") else {
            throw CLIError(message: "missing app name", exitCode: 64)
        }

        var outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var template = AppTemplate.hello
        var force = false

        while let option = parser.next() {
            switch option {
            case "--output":
                outputDirectory = URL(fileURLWithPath: try parser.requireValue(after: option))
            case "--template":
                let rawValue = try parser.requireValue(after: option)
                guard let parsedTemplate = AppTemplate(rawValue: rawValue) else {
                    throw CLIError(message: "unknown template: \(rawValue)", exitCode: 64)
                }
                template = parsedTemplate
            case "--force":
                force = true
            default:
                throw CLIError(message: "unknown option: \(option)", exitCode: 64)
            }
        }

        return NewCommand(
            appName: appName,
            outputDirectory: outputDirectory,
            template: template,
            force: force
        )
    }

    func run() throws {
        let projectDirectory = outputDirectory
            .appendingPathComponent(appName, isDirectory: true)
            .standardizedFileURL
        let project = TemplateProject(
            appName: appName,
            template: template,
            projectDirectory: projectDirectory
        )

        try createDirectory(projectDirectory)
        for file in project.files {
            try write(file, to: projectDirectory)
        }
        _ = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: projectDirectory
        )
        .materialize()

        print("Created \(project.directoryName) at \(projectDirectory.path)")
    }

    private func createDirectory(_ url: URL) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            if force {
                try fileManager.removeItem(at: url)
            } else {
                throw CLIError(message: "directory already exists: \(url.path)", exitCode: 73)
            }
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func write(_ file: TemplateFile, to projectDirectory: URL) throws {
        let url = projectDirectory.appendingPathComponent(file.path)
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try file.contents.write(to: url, atomically: true, encoding: .utf8)
        if file.isExecutable {
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }
}

enum AppTemplate: String {
    case hello
    case basic
    case roadmap
}

struct TemplateFile {
    let path: String
    let contents: String
    let isExecutable: Bool

    init(path: String, contents: String, isExecutable: Bool = false) {
        self.path = path
        self.contents = contents
        self.isExecutable = isExecutable
    }
}

struct TemplateProject {
    let appName: String
    let template: AppTemplate
    let projectDirectory: URL

    var directoryName: String {
        appName
    }

    var files: [TemplateFile] {
        if template == .roadmap {
            return roadmapFiles
        }

        return [
            TemplateFile(path: "Package.swift", contents: packageSwift),
            TemplateFile(path: "README.md", contents: readme),
            TemplateFile(path: "Sources/\(appName)/App.swift", contents: appSwift),
            TemplateFile(path: "Sources/\(appName)/Routes/HomePage.swift", contents: homePageSwift),
        ]
    }

    private var packageSwift: String {
        """
        // swift-tools-version: 6.4

        import PackageDescription

        let package = Package(
            name: "\(appName)",
            platforms: [
                .macOS("26.2"),
            ],
            products: [
                .library(name: "\(appName)", targets: ["\(appName)"]),
            ],
            dependencies: [
                .package(path: "\(FileManager.default.currentDirectoryPath)"),
                .package(url: "https://github.com/1amageek/swift-html.git", from: "0.1.0"),
            ],
            targets: [
                .target(
                    name: "\(appName)",
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

    private var readme: String {
        """
        # \(appName)

        Generated by SwiftWebCLI.

        Run from Terminal:

        ```bash
        swift-web dev
        ```

        Build server:

        ```bash
        swift-web build
        ```

        `Package.swift` declares only the app library. `swift-web dev` and `swift-web build` generate `.swiftweb/generated/Package.swift` for launchers, server execution, and WASM runtime builds.
        """
    }

    private var appSwift: String {
        """
        import SwiftWeb

        public struct \(appName): SwiftWeb.App {
            public init() {}

            public var body: some AppContent {
                HomePage()
            }
        }
        """
    }

    private var homePageSwift: String {
        """
        import SwiftHTML
        import SwiftWeb
        import SwiftWebUI

        @Page("/")
        struct HomePage {
            var title: String {
                get async {
                    "Hello World"
                }
            }

            var description: String? {
                get async {
                    "A SwiftWeb page rendered by Vapor and SwiftHTML."
                }
            }

            func body() -> some HTML {
                VStack(alignment: .center, spacing: .large) {
                    div(
                        .style(
                            .maxWidth("560px"),
                            .custom("margin", "80px auto")
                        )
                    ) {
                        Card {
                            VStack(alignment: .center, spacing: .medium) {
                                Badge("SwiftWeb")
                                h1 { "Hello World" }
                                TextBlock("Rendered by SwiftWeb.", tone: .muted)
                            }
                        }
                    }
                }
                .environment(\\.theme, .system)
            }
        }
        """
    }
}
