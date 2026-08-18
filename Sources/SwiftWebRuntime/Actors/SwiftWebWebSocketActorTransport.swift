import ActorSystemCore

/// Multiplexes binary actor frames over one or more authenticated duplex
/// channels. Correlation remains in `ActorSystemCore`; this adapter only maps
/// owned bytes, endpoints, and trusted connection metadata.
public actor SwiftWebWebSocketActorTransport: ActorEndpointLifecycleReportingTransport {
    private enum Phase: Sendable, Equatable {
        case initialized
        case starting
        case running
        case stopped
    }

    private struct ChannelRegistration: Sendable {
        let id: UInt64
        let channel: any SwiftWebActorBinaryChannel
        let metadata: ActorByteBuffer
    }

    private struct ConsumerRegistration: Sendable {
        let channelRegistrationID: UInt64
        let task: Task<Void, Never>
    }

    public nonisolated let incoming: AsyncThrowingStream<ActorInboundFrame, any Error>
    private nonisolated let incomingContinuation:
        AsyncThrowingStream<ActorInboundFrame, any Error>.Continuation
    private let frameCodec: ActorFrameCodec
    private let maximumMetadataBytes: Int
    private let maximumChannels: Int
    private var phase = Phase.initialized
    private var nextChannelRegistrationID: UInt64 = 0
    private var channels: [ActorEndpoint: ChannelRegistration] = [:]
    private var consumers: [ActorEndpoint: ConsumerRegistration] = [:]
    private var endpointTerminationHandler:
        (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?

    public init(
        configuration: ActorSystemConfiguration,
        channels: [(any SwiftWebActorBinaryChannel, ActorByteBuffer)] = []
    ) throws {
        guard configuration.maximumIdentityBytes >= 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket metadata limit is invalid")
            )
        }
        guard configuration.maximumConcurrentInboundCalls > 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket inbound buffer limit is invalid")
            )
        }
        guard configuration.maximumTransportEndpoints > 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket endpoint limit is invalid")
            )
        }
        guard channels.count <= configuration.maximumTransportEndpoints else {
            throw ActorSystemError.overloaded
        }
        let pair = AsyncThrowingStream<ActorInboundFrame, any Error>.makeStream(
            bufferingPolicy: .bufferingOldest(
                configuration.maximumConcurrentInboundCalls
            )
        )
        self.incoming = pair.stream
        self.incomingContinuation = pair.continuation
        self.frameCodec = ActorFrameCodec(configuration: configuration)
        self.maximumMetadataBytes = configuration.maximumIdentityBytes
        self.maximumChannels = configuration.maximumTransportEndpoints
        for (channel, metadata) in channels {
            guard metadata.count <= configuration.maximumIdentityBytes else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("Actor WebSocket metadata exceeds its limit")
                )
            }
            guard self.channels[channel.endpoint] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("Actor WebSocket endpoint is duplicated")
                )
            }
            guard self.nextChannelRegistrationID < UInt64.max else {
                throw ActorSystemError.overloaded
            }
            self.nextChannelRegistrationID += 1
            self.channels[channel.endpoint] = ChannelRegistration(
                id: self.nextChannelRegistrationID,
                channel: channel,
                metadata: metadata
            )
        }
    }

    public func start() async throws {
        guard phase == .initialized else {
            throw ActorSystemError.alreadyStarted
        }
        phase = .starting
        let registrations = channels.values.sorted {
            $0.channel.endpoint.transportSpecificAddress
                < $1.channel.endpoint.transportSpecificAddress
        }
        do {
            for registration in registrations {
                try await registration.channel.start()
                guard phase == .starting,
                      channels[registration.channel.endpoint]?.id == registration.id
                else {
                    throw ActorSystemError.transportClosed
                }
            }
            phase = .running
            for registration in registrations {
                installConsumer(for: registration)
            }
        } catch {
            let rollbackRegistrations: [ChannelRegistration]
            if phase == .starting {
                phase = .stopped
                rollbackRegistrations = Array(channels.values)
                channels.removeAll(keepingCapacity: false)
                endpointTerminationHandler = nil
            } else {
                rollbackRegistrations = []
            }
            for registration in rollbackRegistrations.reversed() {
                await registration.channel.shutdown()
            }
            incomingContinuation.finish(throwing: error)
            throw error
        }
    }

    public func setEndpointTerminationHandler(
        _ handler: (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    ) async {
        endpointTerminationHandler = handler
    }

    public func attach(
        _ channel: any SwiftWebActorBinaryChannel,
        metadata: ActorByteBuffer = ActorByteBuffer()
    ) async throws {
        guard phase != .stopped else {
            throw ActorSystemError.transportClosed
        }
        guard phase != .starting else {
            throw ActorSystemError.notStarted
        }
        guard metadata.count <= maximumMetadataBytes else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket metadata exceeds its limit")
            )
        }
        guard channels[channel.endpoint] == nil else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket endpoint is duplicated")
            )
        }
        guard channels.count < maximumChannels else {
            throw ActorSystemError.overloaded
        }
        guard nextChannelRegistrationID < UInt64.max else {
            throw ActorSystemError.overloaded
        }
        nextChannelRegistrationID += 1
        let registration = ChannelRegistration(
            id: nextChannelRegistrationID,
            channel: channel,
            metadata: metadata
        )
        channels[channel.endpoint] = registration
        guard phase == .running else {
            return
        }
        do {
            try await channel.start()
            guard phase == .running,
                  channels[channel.endpoint]?.id == registration.id
            else {
                await channel.shutdown()
                throw ActorSystemError.transportClosed
            }
            installConsumer(for: registration)
        } catch {
            let stillOwnsChannel = channels[channel.endpoint]?.id == registration.id
            if stillOwnsChannel {
                channels[channel.endpoint] = nil
                await channel.shutdown()
            }
            throw error
        }
    }

    public func detach(endpoint: ActorEndpoint) async {
        guard let registration = channels[endpoint] else {
            return
        }
        let consumer = await channelFailed(
            endpoint: endpoint,
            registrationID: registration.id,
            error: .transportClosed
        )
        consumer?.cancel()
        await consumer?.value
    }

    public func send(
        _ frame: ActorFrame,
        to endpoint: ActorEndpoint
    ) async throws {
        guard phase == .running else {
            throw ActorSystemError.transportClosed
        }
        guard let registration = channels[endpoint] else {
            throw ActorSystemError.transportUnavailable(.swiftWebWebSocket)
        }
        let bytes = try frameCodec.encode(frame)
        try await registration.channel.send(bytes)
    }

    public func shutdown() async {
        guard phase != .stopped else {
            return
        }
        phase = .stopped
        let tasks = consumers.values.map { consumer in consumer.task }
        consumers.removeAll(keepingCapacity: false)
        let registrations = Array(channels.values)
        channels.removeAll(keepingCapacity: false)
        endpointTerminationHandler = nil
        for task in tasks {
            task.cancel()
        }
        for registration in registrations {
            await registration.channel.shutdown()
        }
        for task in tasks {
            await task.value
        }
        incomingContinuation.finish()
    }

    private func installConsumer(for registration: ChannelRegistration) {
        let endpoint = registration.channel.endpoint
        let gate = SwiftWebActorTaskStartGate()
        let task = Task {
            await gate.wait()
            do {
                for try await bytes in registration.channel.incoming {
                    try await self.receive(
                        bytes,
                        endpoint: endpoint,
                        registrationID: registration.id,
                        metadata: registration.metadata
                    )
                }
                _ = await self.channelFailed(
                    endpoint: endpoint,
                    registrationID: registration.id,
                    error: .transportClosed
                )
            } catch let error as ActorSystemError {
                _ = await self.channelFailed(
                    endpoint: endpoint,
                    registrationID: registration.id,
                    error: error
                )
            } catch {
                _ = await self.channelFailed(
                    endpoint: endpoint,
                    registrationID: registration.id,
                    error: .transportClosed
                )
            }
        }
        consumers[endpoint] = ConsumerRegistration(
            channelRegistrationID: registration.id,
            task: task
        )
        gate.start()
    }

    private func receive(
        _ bytes: ActorByteBuffer,
        endpoint: ActorEndpoint,
        registrationID: UInt64,
        metadata: ActorByteBuffer
    ) async throws {
        guard phase == .running,
              channels[endpoint]?.id == registrationID
        else {
            throw ActorSystemError.transportClosed
        }
        let frame = try frameCodec.decode(bytes)
        let result = incomingContinuation.yield(
            ActorInboundFrame(
                frame: frame,
                transport: .swiftWebWebSocket,
                replyEndpoint: endpoint,
                metadata: metadata
            )
        )
        switch result {
        case .enqueued:
            return
        case .dropped:
            throw ActorSystemError.overloaded
        case .terminated:
            throw ActorSystemError.transportClosed
        @unknown default:
            throw ActorSystemError.transportClosed
        }
    }

    private func channelFailed(
        endpoint: ActorEndpoint,
        registrationID: UInt64,
        error: ActorSystemError
    ) async -> Task<Void, Never>? {
        guard channels[endpoint]?.id == registrationID,
              let registration = channels.removeValue(forKey: endpoint)
        else {
            return nil
        }
        let handler = phase == .running ? endpointTerminationHandler : nil
        if let handler {
            // The Core handler acknowledges registry admission; Core owns and
            // joins the resulting cleanup task. This consumer must not inherit
            // ownership of endpoint cleanup that can wait for channel sends.
            await handler(endpoint, error)
        }
        await registration.channel.shutdown()
        guard consumers[endpoint]?.channelRegistrationID == registrationID else {
            return nil
        }
        return consumers.removeValue(forKey: endpoint)?.task
    }
}

#if SWIFTWEB_ACTORS
extension SwiftWebWebSocketActorTransport: SwiftWebActorChannelAttaching {}
#endif
