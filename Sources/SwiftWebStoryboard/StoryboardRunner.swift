import Foundation
import SwiftWebDevelopment

/// Generates a managed SwiftWebUI component storyboard and, optionally,
/// runs the SwiftWeb development runtime against it.
public struct StoryboardRunner {
    public struct Configuration: Sendable {
        public var packageDirectory: URL
        public var storyboardDirectory: URL?
        public var scratchDirectory: URL?
        public var host: String
        public var port: Int
        public var runsServer: Bool
        public var force: Bool

        public init(
            packageDirectory: URL,
            storyboardDirectory: URL? = nil,
            scratchDirectory: URL? = nil,
            host: String = "127.0.0.1",
            port: Int = 3001,
            runsServer: Bool = true,
            force: Bool = false
        ) {
            self.packageDirectory = packageDirectory
            self.storyboardDirectory = storyboardDirectory
            self.scratchDirectory = scratchDirectory
            self.host = host
            self.port = port
            self.runsServer = runsServer
            self.force = force
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func run() throws {
        let workspace = StoryboardWorkspace(packageDirectory: configuration.packageDirectory)
        let swiftWebDirectory = try workspace.resolveSwiftWebPackageDirectory()
        let directory = configuration.storyboardDirectory ?? workspace.defaultStoryboardDirectory
        let project = StoryboardProject(
            projectDirectory: directory,
            swiftWebPackageDirectory: swiftWebDirectory
        )

        try project.materialize(force: configuration.force)
        _ = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: directory
        )
        .materialize()

        print("SwiftWeb storyboard generated at \(directory.path)")
        if !configuration.runsServer {
            print("Run: swift-web storyboard --package-path \(configuration.packageDirectory.path)")
            return
        }

        print("SwiftWeb storyboard starting at http://\(configuration.host):\(configuration.port)")
        let runtimeConfiguration = SwiftWebDevRuntimeConfiguration(
            packageDirectory: directory,
            scratchDirectory: configuration.scratchDirectory,
            product: "app-server",
            host: configuration.host,
            port: configuration.port
        )

        do {
            try SwiftWebDevRuntime(configuration: runtimeConfiguration).run()
        } catch let error as SwiftWebDevRuntimeError {
            throw StoryboardError.runtime(error)
        }
    }
}
