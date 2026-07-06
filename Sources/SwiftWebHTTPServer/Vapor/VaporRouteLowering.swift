import HTTPTypes
import Logging
import RoutingKit
import WebSocketKit
import SwiftWebCore
import Vapor

/// Registers the app's collected host-neutral routes on the Vapor router.
enum VaporRouteLowering {
    static func lower(_ routes: [WebRoute], onto application: VaporWebApplication) {
        for route in routes {
            register(route, on: application)
        }
    }

    private static func register(_ route: WebRoute, on application: VaporWebApplication) {
        let vaporPath = route.path.map(vaporComponent)
        switch route.handler {
        case .http(let handler):
            application.vapor.on(
                route.method,
                vaporPath,
                body: vaporBody(route.bodyStrategy)
            ) { request async throws -> Vapor.Response in
                let webRequest = application.webRequest(for: request)
                webRequest.parameters = parameters(from: request, path: route.path)
                let webResponse: WebResponse
                do {
                    webResponse = try await handler(webRequest)
                } catch let abort as SwiftWebHostKit.Abort {
                    throw Vapor.Abort(abort.status, reason: abort.reason)
                }
                request.storage[SwiftWebHandledResponseKey.self] = webResponse
                return VaporWebResponseConversion.vaporResponse(from: webResponse)
            }
        case .webSocket(let shouldUpgrade, let onUpgrade):
            application.vapor.webSocket(
                vaporPath,
                shouldUpgrade: { request async throws -> HTTPFields? in
                    let webRequest = application.webRequest(for: request)
                    webRequest.parameters = parameters(from: request, path: route.path)
                    do {
                        return try await shouldUpgrade(webRequest)
                    } catch let abort as SwiftWebHostKit.Abort {
                        throw Vapor.Abort(abort.status, reason: abort.reason)
                    }
                },
                onUpgrade: { request, socket async in
                    let webRequest = application.webRequest(for: request)
                    webRequest.parameters = parameters(from: request, path: route.path)
                    await onUpgrade(webRequest, VaporWebSocketChannel(socket: socket, logger: request.logger))
                }
            )
        }
    }

    private static func vaporComponent(_ component: WebPathComponent) -> PathComponent {
        switch component {
        case .constant(let value):
            .constant(value)
        case .parameter(let name):
            .parameter(name)
        case .anything:
            .anything
        case .catchall:
            .catchall
        }
    }

    private static func vaporBody(_ strategy: WebBodyStreamStrategy) -> Vapor.HTTPBodyStreamStrategy {
        switch strategy {
        case .collect(let maxSize):
            .collect(maxSize: maxSize.map { ByteCount(value: $0) })
        case .stream:
            .stream
        }
    }

    private static func parameters(from request: Vapor.Request, path: [WebPathComponent]) -> WebPathParameters {
        var parameters = WebPathParameters()
        for component in path {
            if case .parameter(let name) = component, let value = request.parameters.get(name) {
                parameters.set(name, to: value)
            }
        }
        return parameters
    }
}

struct VaporWebSocketChannel: WebSocketChannel {
    let socket: WebSocket
    let logger: Logger

    func send(_ text: String) async throws {
        try await socket.send(text)
    }

    func onText(_ handler: @Sendable @escaping (String) async throws -> Void) {
        socket.onText { _, text async in
            do {
                try await handler(text)
            } catch {
                logger.error("WebSocket text handler failed: \(String(describing: error))")
            }
        }
    }

    func close() async throws {
        try await socket.close()
    }
}
