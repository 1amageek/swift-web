#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftWebCore

/// The bind address for `App.run()`, resolved the same way the Vapor host
/// did: `--hostname`/`--port` arguments (how `sweb` launches app workers),
/// falling back to 127.0.0.1:8080.
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
    static func run() async throws {
        let address = HTTPServerAddressResolution.resolve()
        try await HTTPServerAppRunner(
            Self(),
            hostname: address.hostname,
            port: address.port
        ).run()
    }

    static func run(clientRuntime: ClientRuntimeConfiguration) async throws {
        let address = HTTPServerAddressResolution.resolve()
        try await HTTPServerAppRunner(
            Self(),
            hostname: address.hostname,
            port: address.port,
            clientRuntime: clientRuntime
        ).run()
    }

    static func main() async throws {
        try await run()
    }
}
