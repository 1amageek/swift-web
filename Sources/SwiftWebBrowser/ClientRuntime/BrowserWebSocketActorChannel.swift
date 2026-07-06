#if os(WASI)
import JavaScriptKit
import SwiftWebActors

/// Drives a `WebSocketActorTransport` over the browser's native WebSocket:
/// the realtime path to Durable-Object-hosted agents. Frames queue until the
/// socket opens; inbound frames feed the transport, which dispatches
/// server-initiated invocations to the bound (client-hosted) actor system.
///
///     let channel = BrowserWebSocketActorChannel(
///         url: "/_swiftweb/actors/ws?actor=\(agentID)",
///         observerID: observer.id
///     )
///     channel.transport.bind(clientSystem)
///     clientSystem.setTransport(channel.transport)
public final class BrowserWebSocketActorChannel: @unchecked Sendable {
    public let transport: WebSocketActorTransport

    // The browser runtime is single-threaded; these are only touched from
    // the JS event loop.
    private var socket: JSObject?
    private var queued: [String] = []
    private var opened = false
    private var retainedClosures: [JSClosure] = []

    public init(url: String, observerID: String? = nil) {
        var sendQueued: (@Sendable (String) -> Void)!
        // The transport outlives `self` setup; route sends through a box so
        // the closure can be created before the socket exists.
        let box = ChannelBox()
        self.transport = WebSocketActorTransport(senderID: observerID) { text in
            box.channel?.sendOrQueue(text)
        }
        box.channel = self
        _ = sendQueued

        guard let socketConstructor = JSObject.global.WebSocket.function else {
            transport.closed(RuntimeError.transportFailed("Browser WebSocket API is not available"))
            return
        }
        let socket = socketConstructor.new(url)
        self.socket = socket

        let onOpen = JSClosure { [weak self] _ in
            self?.flushQueue()
            return .undefined
        }
        let onMessage = JSClosure { [weak self] arguments in
            if let text = arguments.first?.object?.data.string {
                self?.transport.receive(text)
            }
            return .undefined
        }
        let onClose = JSClosure { [weak self] _ in
            self?.transport.closed()
            return .undefined
        }
        retainedClosures = [onOpen, onMessage, onClose]
        socket.onopen = .object(onOpen)
        socket.onmessage = .object(onMessage)
        socket.onclose = .object(onClose)
        socket.onerror = .object(onClose)
    }

    private func sendOrQueue(_ text: String) {
        if opened, let socket {
            _ = socket.send?(text)
        } else {
            queued.append(text)
        }
    }

    private func flushQueue() {
        opened = true
        guard let socket else {
            return
        }
        for frame in queued {
            _ = socket.send?(frame)
        }
        queued.removeAll()
    }
}

private final class ChannelBox: @unchecked Sendable {
    weak var channel: BrowserWebSocketActorChannel?
}
#endif
