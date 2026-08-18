import Logging
@_spi(Hosting) import SwiftWebCore

/// A rendered app bound to a native server configuration.
public struct HTTPServerAppInstallation: Sendable {
    private let serverLifecycle: HTTPServerInstallationLifecycle
    private let renderedApp: RenderedApp
    private let developmentParentMonitor: Task<Void, Never>?

    init(
        server: SwiftWebNIOHTTPServer,
        renderedApp: RenderedApp,
        developmentParentMonitor: Task<Void, Never>?
    ) {
        self.serverLifecycle = HTTPServerInstallationLifecycle(server: server)
        self.renderedApp = renderedApp
        self.developmentParentMonitor = developmentParentMonitor
    }

    public func serve() async throws {
        try await serverLifecycle.serve()
    }

    public func shutdown() async throws {
        await serverLifecycle.shutdown()
        developmentParentMonitor?.cancel()
        let termination = await renderedApp.requestShutdown()
        try await termination.wait()
    }
}

private actor HTTPServerInstallationLifecycle {
    private enum Phase: Sendable, Equatable {
        case initialized
        case serving
        case shuttingDown
        case stopped
    }

    private let server: SwiftWebNIOHTTPServer
    private var phase = Phase.initialized
    private var serveTask: Task<Void, any Error>?
    private var shutdownTask: Task<Void, Never>?

    init(server: SwiftWebNIOHTTPServer) {
        self.server = server
    }

    func serve() async throws {
        guard phase == .initialized else {
            throw HTTPServerInstallationError.alreadyStarted
        }
        phase = .serving
        let task = Task {
            try await server.serve()
        }
        serveTask = task
        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            finishServing()
        } catch {
            finishServing()
            throw error
        }
    }

    func shutdown() async {
        if let shutdownTask {
            await shutdownTask.value
            return
        }
        guard phase != .stopped else {
            return
        }
        phase = .shuttingDown
        let serving = serveTask
        let logger = server.logger
        let task = Task {
            serving?.cancel()
            guard let serving else {
                return
            }
            do {
                try await serving.value
            } catch is CancellationError {
                return
            } catch {
                logger.error(
                    "SwiftWeb server shutdown observed a listener failure: \(String(describing: error))"
                )
            }
        }
        shutdownTask = task
        await task.value
        serveTask = nil
        shutdownTask = nil
        phase = .stopped
    }

    private func finishServing() {
        serveTask = nil
        if phase == .serving {
            phase = .stopped
        }
    }
}

private enum HTTPServerInstallationError: Error, Sendable {
    case alreadyStarted
}
