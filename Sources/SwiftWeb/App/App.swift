import Vapor

public protocol App {
    associatedtype Body: AppContent
    associatedtype Services: AppServices = EmptyAppServices

    init()

    var clientRuntime: ClientRuntimeConfiguration { get }
    /// Defines the app-wide HTTP security policy.
    var security: SecurityConfiguration { get }

    @AppServiceBuilder
    var services: Services { get }

    @AppBuilder
    var body: Body { get }
}

public extension App {
    var clientRuntime: ClientRuntimeConfiguration {
        .disabled
    }

    var security: SecurityConfiguration {
        .defaults
    }

    static func run() async throws {
        try await AppRunner(Self()).run()
    }

    static func run(clientRuntime: ClientRuntimeConfiguration) async throws {
        try await AppRunner(Self(), clientRuntime: clientRuntime).run()
    }

    static func main() async throws {
        try await run()
    }
}

public extension App where Services == EmptyAppServices {
    var services: EmptyAppServices {
        EmptyAppServices()
    }
}
