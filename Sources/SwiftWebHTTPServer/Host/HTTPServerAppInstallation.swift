import NIOHTTPServer

/// A rendered app bound to a native server configuration.
public struct HTTPServerAppInstallation: Sendable {
    let server: NIOHTTPServer
    let handler: SwiftWebHostHTTPHandler
    private let developmentParentMonitor: Task<Void, Never>?

    init(
        server: NIOHTTPServer,
        handler: SwiftWebHostHTTPHandler,
        developmentParentMonitor: Task<Void, Never>?
    ) {
        self.server = server
        self.handler = handler
        self.developmentParentMonitor = developmentParentMonitor
    }

    public func serve() async throws {
        try await server.serve(handler: handler)
    }

    public func shutdown() {
        developmentParentMonitor?.cancel()
    }
}
