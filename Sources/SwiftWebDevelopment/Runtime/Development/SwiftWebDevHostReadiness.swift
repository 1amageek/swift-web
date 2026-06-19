import Foundation
import NIOCore

enum SwiftWebDevHostReadiness {
    static func wait(
        configuration: SwiftWebDevRuntimeConfiguration
    ) async throws -> SocketAddress {
        let deadline = Date().addingTimeInterval(max(configuration.readinessTimeout, 0))
        while Date() < deadline {
            if await statusEndpointResponds(configuration: configuration) {
                return try SocketAddress.makeAddressResolvingHost(
                    probeHost(for: configuration.host),
                    port: configuration.port
                )
            }
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
            } catch {
                throw error
            }
        }

        throw SwiftWebDevRuntimeError.hostReadinessTimeout(
            host: configuration.host,
            port: configuration.port,
            timeout: configuration.readinessTimeout
        )
    }

    private static func statusEndpointResponds(
        configuration: SwiftWebDevRuntimeConfiguration
    ) async -> Bool {
        guard let url = URL(string: "http://\(probeHost(for: configuration.host)):\(configuration.port)/__dev/status") else {
            return false
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 0.5

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode)
            else {
                return false
            }
            _ = try JSONDecoder.swiftWebDevEvent.decode(SwiftWebDevHostStatus.self, from: data)
            return true
        } catch {
            return false
        }
    }

    private static func probeHost(for host: String) -> String {
        switch host {
        case "0.0.0.0", "::", "localhost":
            return "127.0.0.1"
        default:
            return host
        }
    }
}
