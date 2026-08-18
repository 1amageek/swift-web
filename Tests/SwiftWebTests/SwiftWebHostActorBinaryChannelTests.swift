import ActorSystemCore
import SwiftWebActors
import Synchronization
import Testing
@testable import SwiftWebCore

@Suite
struct SwiftWebHostActorBinaryChannelTests {
    @Test
    func carriesOwnedBinaryFramesInBothDirections() async throws {
        let socket = TestWebSocketChannel()
        let channel = try SwiftWebHostActorBinaryChannel(
            endpoint: ActorEndpoint("test-connection"),
            socket: socket,
            maximumFrameBytes: 1_024,
            maximumBufferedFrames: 2
        )
        try await channel.start()

        var iterator = channel.incoming.makeAsyncIterator()
        try await socket.receiveBinary([0x01, 0x02, 0x03])
        #expect(try await iterator.next() == ActorByteBuffer([0x01, 0x02, 0x03]))

        try await channel.send(ActorByteBuffer([0x04, 0x05]))
        #expect(socket.sentBinaryFrames == [[0x04, 0x05]])

        await channel.shutdown()
        #expect(socket.isClosed)
        #expect(try await iterator.next() == nil)
    }

    @Test
    func failsInsteadOfDroppingWhenTheInboundBufferIsFull() async throws {
        let socket = TestWebSocketChannel()
        let channel = try SwiftWebHostActorBinaryChannel(
            endpoint: ActorEndpoint("bounded-connection"),
            socket: socket,
            maximumFrameBytes: 1_024,
            maximumBufferedFrames: 1
        )
        try await channel.start()

        try await socket.receiveBinary([0x01])
        await #expect(throws: ActorSystemError.self) {
            try await socket.receiveBinary([0x02])
        }
        await channel.shutdown()
    }

    @Test
    func multiplexingTransportPreservesEndpointAndAuthenticatedMetadata() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(7)),
            maximumFrameBytes: 1_024,
            maximumPayloadBytes: 512,
            maximumIdentityBytes: 128
        )
        let socket = TestWebSocketChannel()
        let endpoint = ActorEndpoint("authenticated-connection")
        let channel = try SwiftWebHostActorBinaryChannel(
            endpoint: endpoint,
            socket: socket,
            maximumFrameBytes: configuration.maximumFrameBytes,
            maximumBufferedFrames: configuration.maximumConcurrentInboundCalls
        )
        let metadata = ActorByteBuffer([0xAA, 0xBB])
        let transport = try SwiftWebWebSocketActorTransport(
            configuration: configuration,
            channels: [(channel, metadata)]
        )
        try await transport.start()

        let frame = ActorFrame.hello(
            ActorHelloFrame(
                session: ActorSessionID(7),
                maximumWireVersion: ActorFrameCodec.wireVersion
            )
        )
        let codec = ActorFrameCodec(configuration: configuration)
        var iterator = transport.incoming.makeAsyncIterator()
        try await socket.receiveBinary(codec.encode(frame).bytes)
        let inbound = try #require(try await iterator.next())
        #expect(inbound.frame == frame)
        #expect(inbound.transport == .swiftWebWebSocket)
        #expect(inbound.replyEndpoint == endpoint)
        #expect(inbound.metadata == metadata)

        try await transport.send(frame, to: endpoint)
        let encodedReply = try #require(socket.sentBinaryFrames.last)
        #expect(try codec.decode(ActorByteBuffer(encodedReply)) == frame)

        await transport.shutdown()
        #expect(socket.isClosed)
    }

    @Test
    func shutdownWhileAChannelStartsDoesNotResurrectTheTransport() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(8))
        )
        let channel = SuspendedStartActorBinaryChannel(
            endpoint: ActorEndpoint("suspended-start")
        )
        let transport = try SwiftWebWebSocketActorTransport(
            configuration: configuration,
            channels: [(channel, ActorByteBuffer())]
        )
        let startTask = Task {
            try await transport.start()
        }

        var startIterator = channel.startEntered.makeAsyncIterator()
        #expect(await startIterator.next() != nil)
        await transport.shutdown()

        do {
            try await startTask.value
            Issue.record("Transport start must fail after terminal shutdown")
        } catch let error as ActorSystemError {
            #expect(error == .transportClosed)
        } catch {
            Issue.record("Expected ActorSystemError.transportClosed, got \(error)")
        }
        await #expect(throws: ActorSystemError.self) {
            try await transport.send(
                .hello(
                    ActorHelloFrame(
                        session: ActorSessionID(8),
                        maximumWireVersion: ActorFrameCodec.wireVersion
                    )
                ),
                to: channel.endpoint
            )
        }
    }

    @Test
    func attachIsRejectedWhileInitialChannelsAreStarting() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(9))
        )
        let initialChannel = SuspendedStartActorBinaryChannel(
            endpoint: ActorEndpoint("initial-channel")
        )
        let transport = try SwiftWebWebSocketActorTransport(
            configuration: configuration,
            channels: [(initialChannel, ActorByteBuffer())]
        )
        let startTask = Task {
            try await transport.start()
        }

        var startIterator = initialChannel.startEntered.makeAsyncIterator()
        #expect(await startIterator.next() != nil)
        let lateChannel = SuspendedStartActorBinaryChannel(
            endpoint: ActorEndpoint("late-channel")
        )
        do {
            try await transport.attach(lateChannel)
            Issue.record("Attach must not race an in-progress transport start")
        } catch let error as ActorSystemError {
            #expect(error == .notStarted)
        } catch {
            Issue.record("Expected ActorSystemError.notStarted, got \(error)")
        }

        await transport.shutdown()
        _ = await startTask.result
    }

    @Test
    func failedInitialChannelStartRollsBackTheAcquiredChannel() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(13))
        )
        let channel = FailingStartActorBinaryChannel(
            endpoint: ActorEndpoint("failed-initial-start")
        )
        let transport = try SwiftWebWebSocketActorTransport(
            configuration: configuration,
            channels: [(channel, ActorByteBuffer())]
        )

        await #expect(throws: ActorSystemError.self) {
            try await transport.start()
        }

        #expect(channel.didAcquireResource)
        #expect(channel.shutdownCount == 1)
        await transport.shutdown()
        #expect(channel.shutdownCount == 1)
    }

    @Test
    func failedAttachedChannelStartRollsBackTheAcquiredChannel() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(14))
        )
        let transport = try SwiftWebWebSocketActorTransport(configuration: configuration)
        try await transport.start()
        let channel = FailingStartActorBinaryChannel(
            endpoint: ActorEndpoint("failed-attached-start")
        )

        await #expect(throws: ActorSystemError.self) {
            try await transport.attach(channel)
        }

        #expect(channel.didAcquireResource)
        #expect(channel.shutdownCount == 1)
        await transport.shutdown()
        #expect(channel.shutdownCount == 1)
    }

    @Test
    func endpointTerminationHandlerRunsBeforeConsumerCancellation() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(10))
        )
        let socket = TestWebSocketChannel()
        let endpoint = ActorEndpoint("terminating-channel")
        let channel = try SwiftWebHostActorBinaryChannel(
            endpoint: endpoint,
            socket: socket,
            maximumFrameBytes: configuration.maximumFrameBytes,
            maximumBufferedFrames: configuration.maximumConcurrentInboundCalls
        )
        let transport = try SwiftWebWebSocketActorTransport(
            configuration: configuration,
            channels: [(channel, ActorByteBuffer())]
        )
        let cancellationPair = AsyncStream<Bool>.makeStream(
            bufferingPolicy: .bufferingNewest(1)
        )
        await transport.setEndpointTerminationHandler { reportedEndpoint, _ in
            #expect(reportedEndpoint == endpoint)
            cancellationPair.continuation.yield(Task.isCancelled)
            cancellationPair.continuation.finish()
        }
        try await transport.start()

        var cancellationIterator = cancellationPair.stream.makeAsyncIterator()
        try await socket.close()
        #expect(await cancellationIterator.next() == false)

        await transport.shutdown()
    }

    @Test
    func multiplexingTransportRejectsConnectionsBeyondItsEndpointBound() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(11)),
            maximumTransportEndpoints: 1
        )
        let transport = try SwiftWebWebSocketActorTransport(
            configuration: configuration
        )
        try await transport.start()
        let firstChannel = try SwiftWebHostActorBinaryChannel(
            endpoint: ActorEndpoint("bounded-first"),
            socket: TestWebSocketChannel(),
            maximumFrameBytes: configuration.maximumFrameBytes,
            maximumBufferedFrames: configuration.maximumConcurrentInboundCalls
        )
        try await transport.attach(firstChannel)
        let secondChannel = try SwiftWebHostActorBinaryChannel(
            endpoint: ActorEndpoint("bounded-second"),
            socket: TestWebSocketChannel(),
            maximumFrameBytes: configuration.maximumFrameBytes,
            maximumBufferedFrames: configuration.maximumConcurrentInboundCalls
        )

        do {
            try await transport.attach(secondChannel)
            Issue.record("A channel beyond the configured endpoint bound must be rejected")
        } catch let error as ActorSystemError {
            #expect(error == .overloaded)
        } catch {
            Issue.record("Expected ActorSystemError.overloaded, got \(error)")
        }

        await transport.shutdown()
    }

    @Test
    func shutdownJoinsAnEndpointConsumerDuringTerminationNotification() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(12))
        )
        let socket = TestWebSocketChannel()
        let endpoint = ActorEndpoint("joined-termination")
        let channel = try SwiftWebHostActorBinaryChannel(
            endpoint: endpoint,
            socket: socket,
            maximumFrameBytes: configuration.maximumFrameBytes,
            maximumBufferedFrames: configuration.maximumConcurrentInboundCalls
        )
        let transport = try SwiftWebWebSocketActorTransport(
            configuration: configuration,
            channels: [(channel, ActorByteBuffer())]
        )
        let gate = EndpointTerminationGate()
        await transport.setEndpointTerminationHandler { _, _ in
            await gate.wait()
        }
        try await transport.start()
        var enteredIterator = gate.entered.makeAsyncIterator()
        try await socket.close()
        #expect(await enteredIterator.next() != nil)

        let completed = Mutex(false)
        let shutdown = Task {
            await transport.shutdown()
            completed.withLock { $0 = true }
        }
        for _ in 0..<100 {
            await Task.yield()
        }
        #expect(!completed.withLock { $0 })

        await gate.open()
        await shutdown.value
        #expect(completed.withLock { $0 })
    }
}

private actor EndpointTerminationGate {
    nonisolated let entered: AsyncStream<Void>
    private let enteredContinuation: AsyncStream<Void>.Continuation
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init() {
        let pair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.entered = pair.stream
        self.enteredContinuation = pair.continuation
    }

    func wait() async {
        enteredContinuation.yield(())
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func open() {
        let continuation = releaseContinuation
        releaseContinuation = nil
        enteredContinuation.finish()
        continuation?.resume()
    }
}

private final class SuspendedStartActorBinaryChannel: SwiftWebActorBinaryChannel, Sendable {
    private struct State: Sendable {
        var isShutdown = false
    }

    let endpoint: ActorEndpoint
    let incoming: AsyncThrowingStream<ActorByteBuffer, any Error>
    let startEntered: AsyncStream<Void>

    private let state = Mutex(State())
    private let startRelease: AsyncStream<Void>
    private let incomingContinuation:
        AsyncThrowingStream<ActorByteBuffer, any Error>.Continuation
    private let startEnteredContinuation: AsyncStream<Void>.Continuation
    private let startReleaseContinuation: AsyncStream<Void>.Continuation

    init(endpoint: ActorEndpoint) {
        self.endpoint = endpoint
        let incomingPair = AsyncThrowingStream<ActorByteBuffer, any Error>.makeStream()
        self.incoming = incomingPair.stream
        self.incomingContinuation = incomingPair.continuation
        let startPair = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.startEntered = startPair.stream
        self.startEnteredContinuation = startPair.continuation
        let releasePair = AsyncStream<Void>.makeStream()
        self.startRelease = releasePair.stream
        self.startReleaseContinuation = releasePair.continuation
    }

    func start() async throws {
        startEnteredContinuation.yield(())
        var releaseIterator = startRelease.makeAsyncIterator()
        _ = await releaseIterator.next()
        guard !state.withLock({ $0.isShutdown }) else {
            throw ActorSystemError.transportClosed
        }
    }

    func send(_ bytes: ActorByteBuffer) async throws {
        _ = bytes
        guard !state.withLock({ $0.isShutdown }) else {
            throw ActorSystemError.transportClosed
        }
    }

    func shutdown() async {
        let shouldFinish = state.withLock { state in
            guard !state.isShutdown else {
                return false
            }
            state.isShutdown = true
            return true
        }
        guard shouldFinish else {
            return
        }
        incomingContinuation.finish()
        startEnteredContinuation.finish()
        startReleaseContinuation.finish()
    }
}

private final class FailingStartActorBinaryChannel: SwiftWebActorBinaryChannel, Sendable {
    private struct State: Sendable {
        var didAcquireResource = false
        var shutdownCount = 0
    }

    let endpoint: ActorEndpoint
    let incoming: AsyncThrowingStream<ActorByteBuffer, any Error>
    private let incomingContinuation:
        AsyncThrowingStream<ActorByteBuffer, any Error>.Continuation
    private let state = Mutex(State())

    init(endpoint: ActorEndpoint) {
        self.endpoint = endpoint
        let pair = AsyncThrowingStream<ActorByteBuffer, any Error>.makeStream()
        self.incoming = pair.stream
        self.incomingContinuation = pair.continuation
    }

    var didAcquireResource: Bool {
        state.withLock { $0.didAcquireResource }
    }

    var shutdownCount: Int {
        state.withLock { $0.shutdownCount }
    }

    func start() async throws {
        state.withLock { $0.didAcquireResource = true }
        throw ActorSystemError.transportClosed
    }

    func send(_ bytes: ActorByteBuffer) async throws {
        _ = bytes
        throw ActorSystemError.transportClosed
    }

    func shutdown() async {
        let shouldFinish = state.withLock { state -> Bool in
            guard state.shutdownCount == 0 else {
                return false
            }
            state.shutdownCount = 1
            return true
        }
        if shouldFinish {
            incomingContinuation.finish()
        }
    }
}

private final class TestWebSocketChannel: WebSocketChannel, Sendable {
    private struct State: Sendable {
        var sentBinaryFrames: [[UInt8]] = []
        var textHandler: (@Sendable (String) async throws -> Void)?
        var binaryHandler: (@Sendable ([UInt8]) async throws -> Void)?
        var closeHandler: (@Sendable () async -> Void)?
        var isClosed = false
    }

    private let state = Mutex(State())

    var sentBinaryFrames: [[UInt8]] {
        state.withLock { $0.sentBinaryFrames }
    }

    var isClosed: Bool {
        state.withLock { $0.isClosed }
    }

    func send(_ text: String) async throws {
        _ = text
    }

    func send(_ bytes: [UInt8]) async throws {
        state.withLock { $0.sentBinaryFrames.append(bytes) }
    }

    func onText(_ handler: @Sendable @escaping (String) async throws -> Void) {
        state.withLock { $0.textHandler = handler }
    }

    func onBinary(_ handler: @Sendable @escaping ([UInt8]) async throws -> Void) {
        state.withLock { $0.binaryHandler = handler }
    }

    func onClose(_ handler: @Sendable @escaping () async -> Void) async {
        state.withLock { $0.closeHandler = handler }
    }

    func close() async throws {
        let handler = state.withLock { state -> (@Sendable () async -> Void)? in
            guard !state.isClosed else {
                return nil
            }
            state.isClosed = true
            return state.closeHandler
        }
        await handler?()
    }

    func receiveBinary(_ bytes: [UInt8]) async throws {
        guard let handler = state.withLock({ $0.binaryHandler }) else {
            throw ActorSystemError.notStarted
        }
        try await handler(bytes)
    }
}
