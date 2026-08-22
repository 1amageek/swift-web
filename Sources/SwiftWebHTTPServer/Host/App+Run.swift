#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
// Importing the host module also provides the core vocabulary app launchers
// use, including App.run and client runtime configuration.
@_exported import SwiftWebCore

/// The bind address for `App.run()`, resolved from `--hostname` and `--port`
/// arguments before falling back to 127.0.0.1:8080.
enum HTTPServerAddressResolution {
    static let defaultHostname = "127.0.0.1"
    static let defaultPort = 8080

    static func resolve(
        arguments: [String] = CommandLine.arguments
    ) -> (hostname: String, port: Int) {
        var hostname = defaultHostname
        var port = defaultPort
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--hostname":
                if let value = iterator.next() {
                    hostname = value
                }
            case "--port":
                if let value = iterator.next(), let parsed = Int(value) {
                    port = parsed
                }
            default:
                continue
            }
        }
        return (hostname, port)
    }
}

public extension App {
    func run(
        transport: HTTPServerTransportConfiguration = .plaintext
    ) async throws {
        let address = HTTPServerAddressResolution.resolve()
        try await HTTPServerHost(
            hostname: address.hostname,
            port: address.port,
            transport: transport
        ).run(self)
    }

    func run(
        clientRuntime: ClientRuntimeConfiguration,
        transport: HTTPServerTransportConfiguration = .plaintext
    ) async throws {
        let address = HTTPServerAddressResolution.resolve()
        try await HTTPServerHost(
            hostname: address.hostname,
            port: address.port,
            transport: transport,
            clientRuntime: clientRuntime
        ).run(self)
    }

    static func run(
        transport: HTTPServerTransportConfiguration = .plaintext
    ) async throws {
        try await Self().run(transport: transport)
    }

    static func run(
        clientRuntime: ClientRuntimeConfiguration,
        transport: HTTPServerTransportConfiguration = .plaintext
    ) async throws {
        try await Self().run(
            clientRuntime: clientRuntime,
            transport: transport
        )
    }

    static func main() async throws {
        try await run()
    }
}
