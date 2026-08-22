import TLS
import TLSNIO

/// Selects the byte-stream transport installed before SwiftWeb's HTTP/1.1
/// and WebSocket pipeline.
public struct HTTPServerTransportConfiguration: Sendable {
    enum Storage: Sendable {
        case plaintext
        case tls(
            serverConfiguration: TLSConfiguration,
            handlerConfiguration: TLSNIOHandlerConfiguration
        )
    }

    let storage: Storage

    /// Serves HTTP and WebSocket traffic without transport encryption.
    public static let plaintext = HTTPServerTransportConfiguration(
        storage: .plaintext
    )

    /// Serves HTTPS and WSS traffic with one independent TLS session per
    /// accepted channel.
    ///
    /// SwiftWeb's native host currently supports HTTP/1.1. An empty ALPN list
    /// is normalized to `http/1.1`; explicitly configured protocols must all
    /// be `http/1.1` so the TLS result cannot select an unsupported codec.
    public static func tls(
        _ serverConfiguration: TLSConfiguration,
        handlerConfiguration: TLSNIOHandlerConfiguration = .defaults
    ) throws(HTTPServerTransportConfigurationError) -> HTTPServerTransportConfiguration {
        guard serverConfiguration.identity != nil else {
            throw .missingServerIdentity
        }
        if let unsupportedProtocol = serverConfiguration.alpnProtocols.first(
            where: { $0 != "http/1.1" }
        ) {
            throw .unsupportedApplicationProtocol(unsupportedProtocol)
        }

        var normalizedConfiguration = serverConfiguration
        if normalizedConfiguration.alpnProtocols.isEmpty {
            normalizedConfiguration.alpnProtocols = ["http/1.1"]
        }

        if let error = validationError(
            serverConfiguration: normalizedConfiguration,
            handlerConfiguration: handlerConfiguration
        ) {
            throw .invalidTLSConfiguration(error)
        }

        return HTTPServerTransportConfiguration(
            storage: .tls(
                serverConfiguration: normalizedConfiguration,
                handlerConfiguration: handlerConfiguration
            )
        )
    }

    var isSecure: Bool {
        switch storage {
        case .plaintext:
            false
        case .tls:
            true
        }
    }

    func makeTLSHandler() throws -> TLSNIOHandler? {
        switch storage {
        case .plaintext:
            nil
        case .tls(let serverConfiguration, let handlerConfiguration):
            try TLSNIOHandler(
                serverConfiguration: serverConfiguration,
                configuration: handlerConfiguration
            )
        }
    }

    private static func validationError(
        serverConfiguration: TLSConfiguration,
        handlerConfiguration: TLSNIOHandlerConfiguration
    ) -> TLSError? {
        do {
            _ = try TLSNIOHandler(
                serverConfiguration: serverConfiguration,
                configuration: handlerConfiguration
            )
            return nil
        } catch {
            return error
        }
    }
}
