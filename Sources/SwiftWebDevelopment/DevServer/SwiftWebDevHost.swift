import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Logging
import NIOCore
import NIOHTTPServer
import SwiftWebDevelopmentHooks
import Synchronization

final class SwiftWebDevHost: Sendable {
    private struct State: Sendable {
        var runTask: Task<Void, any Error>?
    }

    private let configuration: SwiftWebDevRuntimeConfiguration
    private let devToken: String
    private let eventLog: SwiftWebDevEventLog
    private let workerRegistry: SwiftWebDevWorkerRegistry
    private let logger: Logger
    private let state = Mutex(State())

    init(
        configuration: SwiftWebDevRuntimeConfiguration,
        devToken: String,
        eventLog: SwiftWebDevEventLog,
        workerRegistry: SwiftWebDevWorkerRegistry,
        logger: Logger
    ) {
        self.configuration = configuration
        self.devToken = devToken
        self.eventLog = eventLog
        self.workerRegistry = workerRegistry
        self.logger = logger
    }

    func start() async throws {
        guard !SwiftWebDevPortProbe.isListening(host: configuration.host, port: configuration.port) else {
            throw SwiftWebDevRuntimeError.portInUse(host: configuration.host, port: configuration.port)
        }

        workerRegistry.markStarting(
            message: "SwiftWeb dev host starting",
            detail: "Public port \(configuration.port) stays alive while workers rebuild."
        )

        var serverConfiguration = try NIOHTTPServerConfiguration(
            bindTarget: .hostAndPort(host: configuration.host, port: configuration.port),
            supportedHTTPVersions: [.http1_1],
            transportSecurity: .plaintext
        )
        // The dev event response is intentionally unbounded. The HTTP server's
        // read-header timer is re-armed after a request body ends, so leaving
        // its default enabled closes an active SSE response after 30 seconds.
        serverConfiguration.connectionTimeouts.readHeader = nil
        let server = NIOHTTPServer(
            logger: logger,
            configuration: serverConfiguration
        )
        let handler = SwiftWebDevHostHTTPHandler(
            devToken: devToken,
            eventLog: eventLog,
            workerRegistry: workerRegistry,
            packageDirectory: configuration.packageDirectory,
            publishedWasmRoot: SwiftWebDevPublishedWasmArtifacts.rootDirectory(
                for: configuration
            ),
            logger: logger
        )

        let runTask = Task {
            try await server.serve(handler: handler)
        }
        state.withLock { state in
            state.runTask = runTask
        }

        let address: SocketAddress
        do {
            address = try await SwiftWebDevHostReadiness.wait(
                configuration: configuration
            )
        } catch {
            await stop()
            throw error
        }

        logger.info(
            "SwiftWeb dev host ready",
            metadata: [
                "host": .string(configuration.host),
                "port": .string(String(configuration.port)),
                "address": .string(String(describing: address)),
            ]
        )
    }

    func stop() async {
        let resources = state.withLock { state in
            let resources = state.runTask
            state.runTask = nil
            return resources
        }

        resources?.cancel()

        if let runTask = resources {
            do {
                try await runTask.value
            } catch {
                if !SwiftWebDevExpectedTermination.isExpected(error) {
                    logger.debug(
                        "SwiftWeb dev host run task ended",
                        metadata: ["error": .string(String(describing: error))]
                    )
                }
            }
        }
    }
}
