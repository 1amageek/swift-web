#if os(WASI) && !hasFeature(Embedded) && SWIFTWEB_LEGACY_ACTORS
import JavaScriptKit
import Synchronization
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
@MainActor
public final class BrowserWebSocketActorChannel {
    public let transport: WebSocketActorTransport

    private var socket: JSObject?
    private var queued: [String] = []
    private var opened = false
    private var retainedClosures: [JSClosure] = []

    public init(url: String, observerID: String? = nil) {
        let box = ChannelBox()
        self.transport = WebSocketActorTransport(senderID: observerID) { text in
            box.send(text)
        }
        box.bind(self)

        guard let socketConstructor = JSObject.global.WebSocket.function else {
            transport.closed(RuntimeError.transportFailed("Browser WebSocket API is not available"))
            return
        }
        let socket = socketConstructor.new(url)

        let onOpen = JSClosure { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.flushQueue()
            }
            return .undefined
        }
        let onMessage = JSClosure { [weak self] arguments in
            if let text = arguments.first?.object?.data.string {
                Task { @MainActor [weak self] in
                    self?.transport.receive(text)
                }
            }
            return .undefined
        }
        let onClose = JSClosure { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.transport.closed()
            }
            return .undefined
        }
        self.socket = socket
        retainedClosures = [onOpen, onMessage, onClose]
        socket.onopen = .object(onOpen)
        socket.onmessage = .object(onMessage)
        socket.onclose = .object(onClose)
        socket.onerror = .object(onClose)
    }

    fileprivate func sendOrQueue(_ text: String) {
        guard opened else {
            queued.append(text)
            return
        }
        if let socket {
            _ = socket.send?(text)
        }
    }

    private func flushQueue() {
        opened = true
        let pending = queued
        queued.removeAll(keepingCapacity: true)
        guard let socket else {
            return
        }
        for frame in pending {
            _ = socket.send?(frame)
        }
    }
}

private final class ChannelBox: Sendable {
    private let sender = Mutex<(@Sendable (String) -> Void)?>(nil)

    func bind(_ channel: BrowserWebSocketActorChannel) {
        sender.withLock { sender in
            sender = { [weak channel] text in
                Task { @MainActor [weak channel] in
                    channel?.sendOrQueue(text)
                }
            }
        }
    }

    func send(_ text: String) {
        let send = sender.withLock { sender in
            sender
        }
        send?(text)
    }
}
#endif
