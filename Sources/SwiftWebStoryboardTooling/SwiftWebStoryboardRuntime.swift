import SwiftWebDevServer
import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import Foundation

public struct SwiftWebStoryboardRuntime: Sendable {
    public let configuration: SwiftWebStoryboardRuntimeConfiguration
    public let observer: SwiftWebStoryboardRuntimeObserver

    public init(
        configuration: SwiftWebStoryboardRuntimeConfiguration,
        observer: SwiftWebStoryboardRuntimeObserver = SwiftWebStoryboardRuntimeObserver()
    ) {
        self.configuration = configuration
        self.observer = observer
    }

    public func run() async throws {
        let swiftWebDirectory = try SwiftWebPackageManifestInspector.packageRoot(
            named: "swift-web",
            from: configuration.packageDirectory
        )
        let directory = configuration.storyboardDirectory
            ?? configuration.packageDirectory
                .appendingPathComponent(".swiftweb", isDirectory: true)
                .appendingPathComponent("storyboard", isDirectory: true)
                .standardizedFileURL
        let scaffold = SwiftWebStoryboardScaffold(
            projectDirectory: directory,
            swiftWebPackageDirectory: swiftWebDirectory
        )

        try scaffold.materialize(force: configuration.force)
        _ = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: directory
        )
        .materialize()

        observer.didGenerate(directory)
        guard configuration.runsServer else {
            observer.didSkipServer(configuration.packageDirectory)
            return
        }

        observer.willStartServer(configuration.host, configuration.port)
        let runtimeConfiguration = SwiftWebDevRuntimeConfiguration(
            packageDirectory: directory,
            scratchDirectory: configuration.scratchDirectory,
            product: "app-server",
            host: configuration.host,
            port: configuration.port
        )
        try await SwiftWebDevRuntime(configuration: runtimeConfiguration).run()
    }
}
