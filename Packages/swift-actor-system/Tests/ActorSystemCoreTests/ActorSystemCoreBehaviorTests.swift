@testable import ActorSystemCore
import ActorSystemTestSupport
import Synchronization
import Testing

@Suite
struct ActorSystemCoreBehaviorTests {
    @Test
    func localClaimActivatesBeforeDirectoryLookup() async throws {
        let address = ActorAddress(
            type: ActorTypeID(high: 80, low: 81),
            identity: "virtual"
        )
        let descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: ActorSchemaFingerprint(high: 82, low: 83),
            methods: [
                ActorMethodDescriptor(
                    id: ActorMethodID(84),
                    parameterTypeIDs: [],
                    resultTypeID: nil,
                    errorTypeID: nil
                ),
            ]
        )
        let directory = ActorDirectory()
        let target = IncrementTarget(address: address, descriptor: descriptor)
        let interceptor = ActivatingInboundInterceptor(
            address: address,
            directory: directory,
            target: target
        )
        let core = ActorSystemCore(
            directory: directory,
            configuration: configuration(
                session: 80,
                inboundInterceptor: interceptor
            )
        )
        try await core.start()

        let result = try await core.invoke(
            ActorInvocation(
                recipient: address,
                method: ActorMethodID(84),
                schemaFingerprint: descriptor.schemaFingerprint,
                payload: try 1.encodeActorValue()
            )
        )

        #expect(try Int.decodeActorValue(from: result.payload, options: .init()) == 2)
        #expect(await interceptor.activationCount == 1)
        try await core.shutdown()
    }

    @Test
    func shutdownUnblocksATransportThatIsStillStarting() async throws {
        let transport = BlockingStartActorTransport()
        let transportID = ActorTransportID("blocking-start")
        let core = ActorSystemCore(
            transports: [transportID: transport],
            configuration: configuration(session: 81)
        )
        let start = Task {
            try await core.start()
        }
        await transport.waitUntilStartIsEntered()

        try await core.shutdown()

        #expect(await transport.shutdownCount == 1)
        do {
            try await start.value
            Issue.record("Expected startup to fail during shutdown")
        } catch let error as ActorSystemError {
            #expect(error.code == .shuttingDown)
        } catch {
            Issue.record("Unexpected startup error: \(error)")
        }
    }

    @Test
    func transportStartCallbackCannotWaitForItsOwnCoreTermination() async throws {
        let transport = ShutdownRequestingStartActorTransport()
        let transportID = ActorTransportID("shutdown-requesting-start")
        let core = ActorSystemCore(
            transports: [transportID: transport],
            configuration: configuration(session: 181)
        )
        transport.install(core)

        let start = Task {
            try await core.start()
        }
        await eventually { transport.reentrantWaitError != nil }

        #expect(transport.reentrantWaitError == .reentrantWait)
        let termination = try #require(transport.requestedTermination)
        try await termination.wait()
        do {
            try await start.value
            Issue.record("Expected startup to be interrupted by terminal cleanup")
        } catch let error as ActorSystemError {
            #expect(error.code == .shuttingDown)
        } catch {
            Issue.record("Unexpected startup error: \(error)")
        }
        #expect(transport.shutdownCount == 1)
        transport.install(nil)
    }

    @Test
    func shutdownTracksAnInboundCallUntilItsReplyFinishes() async throws {
        let scheduler = ActorInboundScheduler(
            maximumConcurrentCalls: 1,
            maximumRetainedResults: 0
        )
        let replyGate = ManualReplyGate()
        try await scheduler.submit(
            callID: ActorCallID(session: ActorSessionID(82), sequence: 1),
            transport: ActorTransportID("reply-tracking"),
            endpoint: ActorEndpoint("reply-peer"),
            reply: { _ in
                await replyGate.waitForRelease()
            },
            operation: {
                .success(ActorInvocationResult())
            }
        )
        await replyGate.waitUntilEntered()
        let didFinish = Mutex(false)
        let shutdown = Task {
            let tasks = await scheduler.stopAcceptingAndCancel()
            for task in tasks {
                await task.value
            }
            didFinish.withLock { $0 = true }
        }
        await Task.yield()
        #expect(!didFinish.withLock { $0 })

        await replyGate.release()
        await shutdown.value
        #expect(didFinish.withLock { $0 })
    }

    @Test
    func loopbackTransportRejectsAnUnknownDestinationEndpoint() async throws {
        let first = LoopbackActorTransport(
            transportID: ActorTransportID("loopback-first"),
            endpoint: ActorEndpoint("loopback-first-endpoint")
        )
        let second = LoopbackActorTransport(
            transportID: ActorTransportID("loopback-second"),
            endpoint: ActorEndpoint("loopback-second-endpoint")
        )
        try first.connect(to: second)
        try second.connect(to: first)
        try await first.start()
        try await second.start()

        await #expect(throws: ActorSystemError.self) {
            try await first.send(
                .hello(
                    ActorHelloFrame(
                        session: ActorSessionID(1),
                        maximumWireVersion: ActorFrameCodec.wireVersion
                    )
                ),
                to: ActorEndpoint("unknown-endpoint")
            )
        }

        await first.shutdown()
        await second.shutdown()
    }

    @Test
    func remoteInvocationUsesCoreCorrelationAndPortablePayload() async throws {
        let fixture = try CorePairFixture()
        try await fixture.start()

        let result = try await fixture.client.invoke(
            fixture.invocation(value: 41)
        )

        #expect(try Int.decodeActorValue(from: result.payload, options: .init()) == 42)
        #expect(await fixture.target.invocationCount == 1)
        try await fixture.shutdown()
    }

    @Test
    func duplicateInboundCallReplaysOneExecutionResult() async throws {
        let fixture = try CorePairFixture(maximumRetainedInboundResults: 8)
        try await fixture.start()
        let callID = ActorCallID(session: ActorSessionID(99), sequence: 1)
        let frame = ActorFrame.invocation(
            ActorInvocationFrame(
                callID: callID,
                invocation: try fixture.invocation(value: 1),
                remainingTimeoutNanoseconds: nil
            )
        )

        try await fixture.clientTransport.send(frame, to: fixture.serverTransport.endpoint)
        try await fixture.clientTransport.send(frame, to: fixture.serverTransport.endpoint)
        await eventually { await fixture.target.invocationCount == 1 }
        try await fixture.clientTransport.send(frame, to: fixture.serverTransport.endpoint)
        await eventually { await fixture.target.invocationCount == 1 }

        #expect(await fixture.target.invocationCount == 1)
        try await fixture.shutdown()
    }

    @Test
    func schemaMismatchPreservesExpectedAndReceivedFingerprints() async throws {
        let fixture = try CorePairFixture()
        try await fixture.start()
        let received = ActorSchemaFingerprint(high: 20, low: 21)
        let invocation = ActorInvocation(
            recipient: fixture.address,
            method: fixture.method,
            schemaFingerprint: received,
            payload: try 1.encodeActorValue()
        )

        do {
            _ = try await fixture.client.invoke(invocation)
            Issue.record("Expected a schema mismatch")
        } catch let ActorSystemError.schemaMismatch(mismatch) {
            #expect(mismatch.expected == fixture.fingerprint)
            #expect(mismatch.received == received)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        try await fixture.shutdown()
    }

    @Test
    func inboundInterceptorCanRejectBeforeTargetExecution() async throws {
        let interceptor = RejectingInboundInterceptor()
        let fixture = try CorePairFixture(inboundInterceptor: interceptor)
        try await fixture.start()

        do {
            _ = try await fixture.client.invoke(fixture.invocation(value: 1))
            Issue.record("Expected authorization failure")
        } catch let error as ActorSystemError {
            guard case .unauthorized = error else {
                Issue.record("Unexpected actor system error: \(error)")
                try await fixture.shutdown()
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(await interceptor.invocationCount == 1)
        #expect(await fixture.target.invocationCount == 0)
        try await fixture.shutdown()
    }

    @Test
    func localInvocationUsesTheSameInboundInterceptor() async throws {
        let interceptor = RejectingInboundInterceptor()
        let address = ActorAddress(
            type: ActorTypeID(high: 30, low: 31),
            identity: "local"
        )
        let descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: ActorSchemaFingerprint(high: 32, low: 33),
            methods: [
                ActorMethodDescriptor(
                    id: ActorMethodID(34),
                    parameterTypeIDs: [],
                    resultTypeID: nil,
                    errorTypeID: nil
                ),
            ]
        )
        let target = IncrementTarget(address: address, descriptor: descriptor)
        let directory = ActorDirectory()
        try directory.register(target)
        let core = ActorSystemCore(
            directory: directory,
            configuration: configuration(
                session: 4,
                inboundInterceptor: interceptor
            )
        )
        try await core.start()

        do {
            _ = try await core.invoke(
                ActorInvocation(
                    recipient: address,
                    method: ActorMethodID(34),
                    schemaFingerprint: descriptor.schemaFingerprint,
                    payload: try 1.encodeActorValue()
                )
            )
            Issue.record("Expected authorization failure")
        } catch let error as ActorSystemError {
            #expect(error.code == .unauthorized)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(await interceptor.invocationCount == 1)
        #expect(await target.invocationCount == 0)
        try await core.shutdown()
    }

    @Test
    func timeoutFailsPendingCallAndSendsCancellation() async throws {
        let clock = ManualActorClock()
        let transport = SilentActorTransport()
        let transportID = ActorTransportID("silent")
        let address = ActorAddress(
            type: ActorTypeID(high: 1, low: 2),
            identity: "remote"
        )
        let core = ActorSystemCore(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: transportID,
                        endpoint: ActorEndpoint("remote")
                    ),
                ]
            ),
            transports: [transportID: transport],
            configuration: configuration(session: 1, clock: clock)
        )
        try await core.start()
        let task = Task {
            try await core.invoke(
                ActorInvocation(
                    recipient: address,
                    method: ActorMethodID(1),
                    schemaFingerprint: ActorSchemaFingerprint(high: 3, low: 4),
                    payload: ActorByteBuffer()
                ),
                options: ActorCallOptions(timeout: .seconds(5))
            )
        }
        await eventually { transport.sentFrameCount >= 1 }
        await clock.advance(by: .seconds(5))

        do {
            _ = try await task.value
            Issue.record("Expected timeout")
        } catch let error as ActorSystemError {
            #expect(error.code == .timeout)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        await eventually { transport.sentCancellationCount == 1 }
        try await core.shutdown()
    }

    @Test
    func shutdownRetainsACancellationIgnoringRemoteTimeoutUntilItFinishes() async throws {
        let clock = CancellationIgnoringActorClock()
        let transport = SilentActorTransport()
        let transportID = ActorTransportID("retained-timeout")
        let address = ActorAddress(
            type: ActorTypeID(high: 150, low: 151),
            identity: "remote"
        )
        let core = ActorSystemCore(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: transportID,
                        endpoint: ActorEndpoint("remote")
                    ),
                ]
            ),
            transports: [transportID: transport],
            configuration: configuration(session: 16, clock: clock)
        )
        try await core.start()
        let invocation = Task {
            try await core.invoke(
                Self.emptyInvocation(to: address),
                options: ActorCallOptions(timeout: .seconds(5))
            )
        }
        await eventually {
            await clock.sleepEntered && transport.sentInvocationCount == 1
        }

        let termination = core.requestShutdown()
        await eventually { await clock.cancellationObserved }
        #expect(!termination.isTerminated)

        do {
            _ = try await invocation.value
            Issue.record("Expected shutdown to fail the pending invocation")
        } catch let error as ActorSystemError {
            #expect(error.code == .shuttingDown)
        } catch {
            Issue.record("Unexpected pending invocation error: \(error)")
        }

        await clock.release()
        try await termination.wait()
        #expect(termination.isTerminated)
    }

    @Test
    func remoteTimeoutAdmissionFailsBeforeSendingWhenOwnedCapacityIsExhausted() async throws {
        let clock = CancellationIgnoringActorClock()
        let transport = SilentActorTransport()
        let transportID = ActorTransportID("bounded-timeout")
        let endpoint = ActorEndpoint("remote")
        let address = ActorAddress(
            type: ActorTypeID(high: 152, low: 153),
            identity: "remote"
        )
        let core = ActorSystemCore(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: transportID,
                        endpoint: endpoint
                    ),
                ]
            ),
            transports: [transportID: transport],
            configuration: configuration(
                session: 17,
                maximumInFlightCalls: 1,
                clock: clock
            )
        )
        try await core.start()
        let first = Task {
            try await core.invoke(
                Self.emptyInvocation(to: address),
                options: ActorCallOptions(timeout: .seconds(5))
            )
        }
        await eventually {
            await clock.sleepEntered && transport.lastInvocationCallID != nil
        }
        let firstCallID = try #require(transport.lastInvocationCallID)
        try transport.receive(
            ActorInboundFrame(
                frame: .result(
                    ActorResultFrame(
                        callID: firstCallID,
                        outcome: .success(ActorInvocationResult())
                    )
                ),
                transport: transportID,
                replyEndpoint: endpoint
            )
        )
        _ = try await first.value
        await eventually { await clock.cancellationObserved }

        do {
            _ = try await core.invoke(
                Self.emptyInvocation(to: address),
                options: ActorCallOptions(timeout: .seconds(5))
            )
            Issue.record("Expected bounded timeout ownership to reject admission")
        } catch let error as ActorSystemError {
            #expect(error.code == .overloaded)
        } catch {
            Issue.record("Unexpected timeout admission error: \(error)")
        }
        #expect(transport.sentInvocationCount == 1)

        let termination = core.requestShutdown()
        await clock.release()
        try await termination.wait()
    }

    @Test
    func shutdownFailsPendingInvocationExactlyOnce() async throws {
        let transport = SilentActorTransport()
        let transportID = ActorTransportID("silent")
        let address = ActorAddress(
            type: ActorTypeID(high: 1, low: 2),
            identity: "remote"
        )
        let core = ActorSystemCore(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: transportID,
                        endpoint: ActorEndpoint("remote")
                    ),
                ]
            ),
            transports: [transportID: transport],
            configuration: configuration(session: 1)
        )
        try await core.start()
        let task = Task {
            try await core.invoke(
                ActorInvocation(
                    recipient: address,
                    method: ActorMethodID(1),
                    schemaFingerprint: ActorSchemaFingerprint(high: 3, low: 4),
                    payload: ActorByteBuffer()
                )
            )
        }
        await eventually { transport.sentFrameCount == 1 }
        try await core.shutdown()

        do {
            _ = try await task.value
            Issue.record("Expected shutdown failure")
        } catch let error as ActorSystemError {
            guard case .shuttingDown = error else {
                Issue.record("Unexpected actor system error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func shutdownCancelsAndJoinsAnInProgressOutboundSend() async throws {
        let transport = BlockingSendActorTransport()
        let transportID = ActorTransportID("blocking-send")
        let address = ActorAddress(
            type: ActorTypeID(high: 7, low: 8),
            identity: "remote"
        )
        let core = ActorSystemCore(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: transportID,
                        endpoint: ActorEndpoint("remote")
                    ),
                ]
            ),
            transports: [transportID: transport],
            configuration: configuration(session: 8)
        )
        try await core.start()
        let invocation = Task {
            try await core.invoke(Self.emptyInvocation(to: address))
        }
        await transport.waitUntilSendStarts()

        let completion = Mutex(false)
        let shutdown = Task {
            try await core.shutdown()
            completion.withLock { $0 = true }
        }
        await transport.waitUntilSendIsCancelled()
        try await shutdown.value
        #expect(completion.withLock { $0 })
        _ = await invocation.result
    }

    @Test
    func endpointTerminationFailsOnlyCallsForThatEndpoint() async throws {
        let transportID = ActorTransportID("multiplexed")
        let firstEndpoint = ActorEndpoint("connection-a")
        let secondEndpoint = ActorEndpoint("connection-b")
        let firstAddress = ActorAddress(
            type: ActorTypeID(high: 60, low: 61),
            identity: "first"
        )
        let secondAddress = ActorAddress(
            type: ActorTypeID(high: 62, low: 63),
            identity: "second"
        )
        let transport = EndpointReportingActorTransport()
        let outcomes = Mutex<[String: ActorSystemErrorCode]>([:])
        let core = ActorSystemCore(
            router: AddressActorRouter(routes: [
                firstAddress: ActorRoute(
                    transport: transportID,
                    endpoint: firstEndpoint
                ),
                secondAddress: ActorRoute(
                    transport: transportID,
                    endpoint: secondEndpoint
                ),
            ]),
            transports: [transportID: transport],
            configuration: configuration(session: 5)
        )
        try await core.start()
        let first = Task {
            do {
                _ = try await core.invoke(Self.emptyInvocation(to: firstAddress))
            } catch let error as ActorSystemError {
                outcomes.withLock { $0["first"] = error.code }
            } catch {
                Issue.record("Unexpected first endpoint error: \(error)")
            }
        }
        let second = Task {
            do {
                _ = try await core.invoke(Self.emptyInvocation(to: secondAddress))
            } catch let error as ActorSystemError {
                outcomes.withLock { $0["second"] = error.code }
            } catch {
                Issue.record("Unexpected second endpoint error: \(error)")
            }
        }
        await eventually { transport.sentFrameCount == 2 }

        await transport.terminate(firstEndpoint, error: .transportClosed)
        await eventually { outcomes.withLock { $0["first"] != nil } }
        #expect(outcomes.withLock { $0["first"] } == .transportClosed)
        #expect(outcomes.withLock { $0["second"] } == nil)

        await transport.terminate(secondEndpoint, error: .overloaded)
        await eventually { outcomes.withLock { $0["second"] != nil } }
        #expect(outcomes.withLock { $0["second"] } == .overloaded)
        _ = await first.result
        _ = await second.result
        try await core.shutdown()
    }

    @Test
    func singleEndpointTransportClosureCancelsInboundWork() async throws {
        let transportID = ActorTransportID("single-endpoint")
        let endpoint = ActorEndpoint("single-connection")
        let address = ActorAddress(
            type: ActorTypeID(high: 64, low: 65),
            identity: "suspending"
        )
        let descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: ActorSchemaFingerprint(high: 66, low: 67),
            methods: [
                ActorMethodDescriptor(
                    id: ActorMethodID(68),
                    parameterTypeIDs: [],
                    resultTypeID: nil,
                    errorTypeID: nil
                ),
            ]
        )
        let target = SuspendingTarget(address: address, descriptor: descriptor)
        let directory = ActorDirectory()
        try directory.register(target)
        let transport = SilentActorTransport()
        let core = ActorSystemCore(
            directory: directory,
            transports: [transportID: transport],
            configuration: configuration(session: 6)
        )
        try await core.start()
        try transport.receive(
            ActorInboundFrame(
                frame: .invocation(
                    ActorInvocationFrame(
                        callID: ActorCallID(
                            session: ActorSessionID(90),
                            sequence: 1
                        ),
                        invocation: ActorInvocation(
                            recipient: address,
                            method: ActorMethodID(68),
                            schemaFingerprint: descriptor.schemaFingerprint,
                            payload: ActorByteBuffer()
                        ),
                        remainingTimeoutNanoseconds: nil
                    )
                ),
                transport: transportID,
                replyEndpoint: endpoint
            )
        )
        await eventually { await target.invocationCount == 1 }

        await transport.shutdown()

        await eventually { await target.cancellationCount == 1 }
        try await core.shutdown()
    }

    private static func emptyInvocation(to address: ActorAddress) -> ActorInvocation {
        ActorInvocation(
            recipient: address,
            method: ActorMethodID(1),
            schemaFingerprint: ActorSchemaFingerprint(high: 2, low: 3),
            payload: ActorByteBuffer()
        )
    }

    @Test
    func localInvocationUsesTheSameDeadlineContract() async throws {
        let clock = ManualActorClock()
        let address = ActorAddress(
            type: ActorTypeID(high: 40, low: 41),
            identity: "local"
        )
        let descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: ActorSchemaFingerprint(high: 42, low: 43),
            methods: [
                ActorMethodDescriptor(
                    id: ActorMethodID(44),
                    parameterTypeIDs: [],
                    resultTypeID: nil,
                    errorTypeID: nil
                ),
            ]
        )
        let target = SuspendingTarget(address: address, descriptor: descriptor)
        let directory = ActorDirectory()
        try directory.register(target)
        let core = ActorSystemCore(
            directory: directory,
            configuration: configuration(session: 3, clock: clock)
        )
        try await core.start()
        let task = Task {
            try await core.invoke(
                ActorInvocation(
                    recipient: address,
                    method: ActorMethodID(44),
                    schemaFingerprint: descriptor.schemaFingerprint,
                    payload: ActorByteBuffer()
                ),
                options: ActorCallOptions(timeout: .seconds(5))
            )
        }
        await eventually { await target.invocationCount == 1 }
        await clock.advance(by: .seconds(5))

        do {
            _ = try await task.value
            Issue.record("Expected local timeout")
        } catch let error as ActorSystemError {
            #expect(error.code == .timeout)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        await eventually { await target.cancellationCount == 1 }
        try await core.shutdown()
    }

    @Test
    func localInvocationCanRequestShutdownWithoutJoiningItself() async throws {
        let address = ActorAddress(
            type: ActorTypeID(high: 141, low: 142),
            identity: "shutdown-requester"
        )
        let descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: ActorSchemaFingerprint(high: 143, low: 144),
            methods: [
                ActorMethodDescriptor(
                    id: ActorMethodID(145),
                    parameterTypeIDs: [],
                    resultTypeID: nil,
                    errorTypeID: nil
                ),
            ]
        )
        let interceptor = ShutdownRequestingInboundInterceptor()
        let directory = ActorDirectory()
        try directory.register(IncrementTarget(address: address, descriptor: descriptor))
        let core = ActorSystemCore(
            directory: directory,
            configuration: configuration(
                session: 14,
                inboundInterceptor: interceptor
            )
        )
        interceptor.install(core)
        try await core.start()

        let result = try await core.invoke(
            ActorInvocation(
                recipient: address,
                method: ActorMethodID(145),
                schemaFingerprint: descriptor.schemaFingerprint,
                payload: try 1.encodeActorValue()
            )
        )

        #expect(try Int.decodeActorValue(from: result.payload, options: .init()) == 2)
        let termination = try #require(interceptor.requestedTermination)
        #expect(interceptor.reentrantWaitError == .reentrantWait)
        try await termination.wait()
        interceptor.install(nil)
    }

    @Test
    func inlineEndpointTerminationDoesNotJoinTheSendingTask() async throws {
        let transportID = ActorTransportID("inline-termination")
        let endpoint = ActorEndpoint("inline-peer")
        let address = ActorAddress(
            type: ActorTypeID(high: 146, low: 147),
            identity: "remote"
        )
        let transport = InlineTerminatingActorTransport()
        let core = ActorSystemCore(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: transportID,
                        endpoint: endpoint
                    ),
                ]
            ),
            transports: [transportID: transport],
            configuration: configuration(session: 15)
        )
        try await core.start()

        do {
            _ = try await core.invoke(Self.emptyInvocation(to: address))
            Issue.record("Expected inline endpoint termination to fail the invocation")
        } catch let error as ActorSystemError {
            #expect(error.code == .transportClosed)
        } catch {
            Issue.record("Unexpected inline termination error: \(error)")
        }
        try await core.shutdown()
    }

    @Test
    func consumerEndpointNotificationDoesNotOwnCoreCleanupCompletion() async throws {
        let transportID = ActorTransportID("consumer-termination")
        let endpoint = ActorEndpoint("consumer-peer")
        let address = ActorAddress(
            type: ActorTypeID(high: 148, low: 149),
            identity: "remote"
        )
        let transport = ConsumerEndpointTerminatingActorTransport()
        let core = ActorSystemCore(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: transportID,
                        endpoint: endpoint
                    ),
                ]
            ),
            transports: [transportID: transport],
            configuration: configuration(session: 16)
        )
        try await core.start()
        let invocation = Task {
            try await core.invoke(Self.emptyInvocation(to: address))
        }
        await transport.waitUntilSendStarts()

        transport.terminateFromConsumer(endpoint: endpoint)
        await transport.waitUntilNotificationStarts()

        // The transport consumer owns channel closure, while Core owns the
        // admitted endpoint cleanup. Shutdown must not make either task join
        // the other before the consumer can release the suspended send.
        let termination = core.requestShutdown()
        try await termination.wait()

        #expect(transport.consumerCompleted)
        await #expect(throws: ActorSystemError.self) {
            _ = try await invocation.value
        }
    }

    @Test
    func remoteInboundInvocationCanRequestShutdownWithoutJoiningItsSchedulerTask() async throws {
        let interceptor = ShutdownRequestingInboundInterceptor()
        let fixture = try CorePairFixture(inboundInterceptor: interceptor)
        interceptor.install(fixture.server)
        try await fixture.start()

        let invocation = Task {
            try await fixture.client.invoke(fixture.invocation(value: 1))
        }
        await eventually { interceptor.shutdownRequested }

        // Loopback shutdown is intentionally one-sided. First prove the server
        // scheduler can finish, then close the client to release its pending call.
        let serverTermination = try #require(interceptor.requestedTermination)
        #expect(interceptor.reentrantWaitError == .reentrantWait)
        try await serverTermination.wait()
        try await fixture.client.shutdown()
        _ = await invocation.result
        interceptor.install(nil)
    }

    @Test
    func deadlineAdmissionDoesNotStartOperationWithoutCapacityForBothTasks() async throws {
        let registry = ActorInvocationTaskRegistry(maximumCount: 1)
        let operationStarted = Mutex(false)
        let deadline = ActorInvocationDeadline<Int>()

        do {
            _ = try await deadline.run(
                timeout: .seconds(1),
                clock: ManualActorClock(),
                taskRegistry: registry,
                operation: {
                    operationStarted.withLock { $0 = true }
                    return 1
                }
            )
            Issue.record("Expected atomic deadline admission to reject the batch")
        } catch let error as ActorSystemError {
            #expect(error.code == .overloaded)
        } catch {
            Issue.record("Unexpected deadline admission error: \(error)")
        }

        #expect(!operationStarted.withLock { $0 })
        let retainedTasks = registry.stopAcceptingAndCancel()
        #expect(retainedTasks.isEmpty)
    }

    @Test
    func deadlineOperationRemainsOwnedUntilItActuallyFinishes() async throws {
        let clock = ManualActorClock()
        let address = ActorAddress(
            type: ActorTypeID(high: 45, low: 46),
            identity: "cancellation-ignoring"
        )
        let descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: ActorSchemaFingerprint(high: 47, low: 48),
            methods: [
                ActorMethodDescriptor(
                    id: ActorMethodID(49),
                    parameterTypeIDs: [],
                    resultTypeID: nil,
                    errorTypeID: nil
                ),
            ]
        )
        let target = CancellationIgnoringTarget(address: address, descriptor: descriptor)
        let directory = ActorDirectory()
        try directory.register(target)
        let core = ActorSystemCore(
            directory: directory,
            configuration: configuration(session: 4, clock: clock)
        )
        try await core.start()
        let invocation = Task {
            try await core.invoke(
                ActorInvocation(
                    recipient: address,
                    method: ActorMethodID(49),
                    schemaFingerprint: descriptor.schemaFingerprint,
                    payload: ActorByteBuffer()
                ),
                options: ActorCallOptions(timeout: .seconds(5))
            )
        }
        await eventually { await target.invocationCount == 1 }
        await clock.advance(by: .seconds(5))
        do {
            _ = try await invocation.value
            Issue.record("Expected local timeout")
        } catch let error as ActorSystemError {
            guard case .timeout = error else {
                Issue.record("Unexpected actor system error: \(error)")
                return
            }
        }

        let shutdownCompleted = Mutex(false)
        let shutdown = Task {
            try await core.shutdown()
            shutdownCompleted.withLock { $0 = true }
        }
        await eventually { target.cancellationObserved }
        #expect(!shutdownCompleted.withLock { $0 })

        await target.release()
        try await shutdown.value
        #expect(shutdownCompleted.withLock { $0 })
    }

    @Test
    func duplicateActorAddressIsRejectedWithoutReplacingTheTarget() throws {
        let address = ActorAddress(
            type: ActorTypeID(high: 50, low: 51),
            identity: "duplicate"
        )
        let descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: ActorSchemaFingerprint(high: 52, low: 53),
            methods: []
        )
        let first = IncrementTarget(address: address, descriptor: descriptor)
        let second = IncrementTarget(address: address, descriptor: descriptor)
        let directory = ActorDirectory()
        try directory.register(first)

        #expect(throws: ActorSystemError.self) {
            try directory.register(second)
        }
        let retained = directory.target(for: address) as? IncrementTarget
        #expect(retained === first)
    }

    @Test
    func zeroSessionIdentityFailsStartupExplicitly() async {
        let core = ActorSystemCore(configuration: configuration(session: 0))

        do {
            try await core.start()
            Issue.record("Expected session identity failure")
        } catch let error as ActorSystemError {
            guard case .sessionIdentityUnavailable = error else {
                Issue.record("Unexpected actor system error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func invalidConfigurationStartupIsTerminal() async throws {
        let core = ActorSystemCore(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(7)
                ),
                maximumInFlightCalls: 0
            )
        )

        do {
            try await core.start()
            Issue.record("Expected invalid configuration failure")
        } catch let error as ActorSystemError {
            #expect(error.code == .invalidFrame)
        } catch {
            Issue.record("Unexpected startup error: \(error)")
        }

        do {
            try await core.start()
            Issue.record("Expected invalid system instance to remain terminal")
        } catch let error as ActorSystemError {
            #expect(error.code == .shuttingDown)
        } catch {
            Issue.record("Unexpected restart error: \(error)")
        }
        try await core.shutdown()
    }

    @Test
    func failedStartupIsTerminalAndReleasesLocalTargets() async throws {
        let address = ActorAddress(
            type: ActorTypeID(high: 70, low: 71),
            identity: "startup-failure"
        )
        let descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: ActorSchemaFingerprint(high: 72, low: 73),
            methods: []
        )
        let directory = ActorDirectory()
        try directory.register(
            IncrementTarget(address: address, descriptor: descriptor)
        )
        let transportID = ActorTransportID("startup-failure")
        let core = ActorSystemCore(
            directory: directory,
            transports: [
                transportID: FailureInjectingActorTransport(failurePoint: .start),
            ],
            configuration: configuration(session: 6)
        )

        do {
            try await core.start()
            Issue.record("Expected transport startup failure")
        } catch let error as ActorSystemError {
            #expect(error.code == .transportClosed)
        } catch {
            Issue.record("Unexpected startup error: \(error)")
        }
        #expect(directory.target(for: address) == nil)

        do {
            try await core.start()
            Issue.record("Expected failed system instance to remain terminal")
        } catch let error as ActorSystemError {
            #expect(error.code == .shuttingDown)
        } catch {
            Issue.record("Unexpected restart error: \(error)")
        }
        try await core.shutdown()
    }
}

private struct CorePairFixture: Sendable {
    let client: ActorSystemCore
    let server: ActorSystemCore
    let clientTransport: LoopbackActorTransport
    let serverTransport: LoopbackActorTransport
    let target: IncrementTarget
    let address = ActorAddress(
        type: ActorTypeID(high: 10, low: 11),
        identity: "counter"
    )
    let method = ActorMethodID(12)
    let fingerprint = ActorSchemaFingerprint(high: 13, low: 14)

    init(
        maximumRetainedInboundResults: Int = 4_096,
        inboundInterceptor: any ActorInboundInvocationInterceptor = DirectActorInboundInvocationInterceptor()
    ) throws {
        let clientTransportID = ActorTransportID("client")
        let serverTransportID = ActorTransportID("server")
        let clientTransport = LoopbackActorTransport(
            transportID: clientTransportID,
            endpoint: ActorEndpoint("client")
        )
        let serverTransport = LoopbackActorTransport(
            transportID: serverTransportID,
            endpoint: ActorEndpoint("server")
        )
        try clientTransport.connect(to: serverTransport)
        try serverTransport.connect(to: clientTransport)
        let directory = ActorDirectory()
        let target = IncrementTarget(
            address: address,
            descriptor: ActorTypeDescriptor(
                id: address.type,
                schemaFingerprint: fingerprint,
                methods: [
                    ActorMethodDescriptor(
                        id: method,
                        parameterTypeIDs: [],
                        resultTypeID: nil,
                        errorTypeID: nil
                    ),
                ]
            )
        )
        try directory.register(target)
        self.clientTransport = clientTransport
        self.serverTransport = serverTransport
        self.target = target
        self.client = ActorSystemCore(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: clientTransportID,
                        endpoint: serverTransport.endpoint
                    ),
                ]
            ),
            transports: [clientTransportID: clientTransport],
            configuration: configuration(
                session: 1,
                maximumRetainedInboundResults: maximumRetainedInboundResults
            )
        )
        self.server = ActorSystemCore(
            directory: directory,
            transports: [serverTransportID: serverTransport],
            configuration: configuration(
                session: 2,
                maximumRetainedInboundResults: maximumRetainedInboundResults,
                inboundInterceptor: inboundInterceptor
            )
        )
    }

    func start() async throws {
        try await server.start()
        try await client.start()
    }

    func shutdown() async throws {
        try await client.shutdown()
        try await server.shutdown()
    }

    func invocation(value: Int) throws -> ActorInvocation {
        ActorInvocation(
            recipient: address,
            method: method,
            schemaFingerprint: fingerprint,
            payload: try value.encodeActorValue()
        )
    }
}

private actor IncrementTarget: ActorInvocationTarget {
    nonisolated let address: ActorAddress
    nonisolated let descriptor: ActorTypeDescriptor
    nonisolated private let cancellationState = Mutex(false)
    private(set) var invocationCount = 0

    init(address: ActorAddress, descriptor: ActorTypeDescriptor) {
        self.address = address
        self.descriptor = descriptor
    }

    func invoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws -> ActorInvocationResult {
        invocationCount += 1
        let value = try Int.decodeActorValue(
            from: invocation.payload,
            options: .init()
        )
        return ActorInvocationResult(payload: try (value + 1).encodeActorValue())
    }
}

private actor SuspendingTarget: ActorInvocationTarget {
    nonisolated let address: ActorAddress
    nonisolated let descriptor: ActorTypeDescriptor
    private(set) var invocationCount = 0
    private(set) var cancellationCount = 0

    init(address: ActorAddress, descriptor: ActorTypeDescriptor) {
        self.address = address
        self.descriptor = descriptor
    }

    func invoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws -> ActorInvocationResult {
        invocationCount += 1
        do {
            try await Task.sleep(for: .seconds(60))
            return ActorInvocationResult()
        } catch is CancellationError {
            cancellationCount += 1
            throw CancellationError()
        }
    }
}

private actor CancellationIgnoringTarget: ActorInvocationTarget {
    nonisolated let address: ActorAddress
    nonisolated let descriptor: ActorTypeDescriptor
    nonisolated private let cancellationState = Mutex(false)
    private(set) var invocationCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    init(address: ActorAddress, descriptor: ActorTypeDescriptor) {
        self.address = address
        self.descriptor = descriptor
    }

    func invoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws -> ActorInvocationResult {
        _ = invocation
        _ = context
        invocationCount += 1
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            self.cancellationState.withLock { $0 = true }
        }
        return ActorInvocationResult()
    }

    nonisolated var cancellationObserved: Bool {
        cancellationState.withLock { $0 }
    }

    func release() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }
}

private actor CancellationIgnoringActorClock: ActorClock {
    private var continuation: CheckedContinuation<Void, any Error>?
    private(set) var sleepEntered = false
    private(set) var cancellationObserved = false

    func sleep(for duration: Duration) async throws {
        _ = duration
        sleepEntered = true
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
            }
        } onCancel: {
            Task { await self.recordCancellation() }
        }
    }

    func release() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }

    private func recordCancellation() {
        cancellationObserved = true
    }
}

private actor RejectingInboundInterceptor: ActorInboundInvocationInterceptor {
    private(set) var invocationCount = 0

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        invocationCount += 1
        throw ActorSystemError.unauthorized
    }
}

private final class ShutdownRequestingInboundInterceptor:
    ActorInboundInvocationInterceptor,
    Sendable
{
    private let core = Mutex<ActorSystemCore?>(nil)
    private let didRequestShutdown = Mutex(false)
    private let termination = Mutex<ActorSystemTermination?>(nil)
    private let waitError = Mutex<ActorSystemTerminationError?>(nil)

    var shutdownRequested: Bool {
        didRequestShutdown.withLock { $0 }
    }

    var requestedTermination: ActorSystemTermination? {
        termination.withLock { $0 }
    }

    var reentrantWaitError: ActorSystemTerminationError? {
        waitError.withLock { $0 }
    }

    func install(_ core: ActorSystemCore?) {
        self.core.withLock { $0 = core }
    }

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        _ = (invocation, context)
        if let core = core.withLock({ $0 }) {
            let termination = core.requestShutdown()
            self.termination.withLock { $0 = termination }
            do {
                try await termination.wait()
                Issue.record("Expected an actor-owned termination wait to fail")
            } catch let error as ActorSystemTerminationError {
                waitError.withLock { $0 = error }
            }
            didRequestShutdown.withLock { $0 = true }
        }
        return try await execution()
    }
}

private actor ActivatingInboundInterceptor:
    ActorInboundInvocationInterceptor,
    ActorLocalInvocationClaiming
{
    private let address: ActorAddress
    private let directory: ActorDirectory
    private let target: IncrementTarget
    private(set) var activationCount = 0

    init(
        address: ActorAddress,
        directory: ActorDirectory,
        target: IncrementTarget
    ) {
        self.address = address
        self.directory = directory
        self.target = target
    }

    func claimsLocalInvocation(for recipient: ActorAddress) -> Bool {
        recipient == address
    }

    func intercept(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext,
        execution: ActorInvocationExecution
    ) async throws -> ActorInvocationResult {
        if directory.target(for: address) == nil {
            try directory.register(target)
            activationCount += 1
        }
        return try await execution()
    }
}

private actor ManualReplyGate {
    private var entered = false
    private var released = false
    private var entryWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitForRelease() async {
        entered = true
        let waiters = entryWaiters
        entryWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
        guard !released else {
            return
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func waitUntilEntered() async {
        guard !entered else {
            return
        }
        await withCheckedContinuation { continuation in
            entryWaiters.append(continuation)
        }
    }

    func release() {
        released = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private actor BlockingStartActorTransport: ActorTransport {
    nonisolated let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let incomingContinuation:
        AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private var startEntered = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var startContinuation: CheckedContinuation<Void, Never>?
    private(set) var shutdownCount = 0

    init() {
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream()
        incoming = stream.stream
        incomingContinuation = stream.continuation
    }

    func start() async throws {
        startEntered = true
        let waiters = startWaiters
        startWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
        try Task.checkCancellation()
    }

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        _ = frame
        _ = endpoint
        throw ActorSystemError.transportClosed
    }

    func waitUntilStartIsEntered() async {
        guard !startEntered else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func shutdown() async {
        shutdownCount += 1
        startContinuation?.resume()
        startContinuation = nil
        incomingContinuation.finish()
    }
}

private final class ShutdownRequestingStartActorTransport: ActorTransport, Sendable {
    private struct State: Sendable {
        var core: ActorSystemCore?
        var termination: ActorSystemTermination?
        var waitError: ActorSystemTerminationError?
        var shutdownCount = 0
    }

    let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let incomingContinuation: AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let state = Mutex(State())

    init() {
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream()
        self.incoming = stream.stream
        self.incomingContinuation = stream.continuation
    }

    var shutdownRequested: Bool {
        state.withLock { $0.termination != nil }
    }

    var requestedTermination: ActorSystemTermination? {
        state.withLock { $0.termination }
    }

    var reentrantWaitError: ActorSystemTerminationError? {
        state.withLock { $0.waitError }
    }

    var shutdownCount: Int {
        state.withLock { $0.shutdownCount }
    }

    func install(_ core: ActorSystemCore?) {
        state.withLock { $0.core = core }
    }

    func start() async throws {
        guard let core = state.withLock({ $0.core }) else {
            throw ActorSystemError.notStarted
        }
        let termination = core.requestShutdown()
        state.withLock { $0.termination = termination }
        do {
            try await termination.wait()
            Issue.record("Expected a start-owned termination wait to fail")
        } catch let error as ActorSystemTerminationError {
            state.withLock { $0.waitError = error }
        }
    }

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        _ = (frame, endpoint)
        throw ActorSystemError.transportClosed
    }

    func shutdown() async {
        let shouldFinish = state.withLock { state -> Bool in
            state.shutdownCount += 1
            return state.shutdownCount == 1
        }
        if shouldFinish {
            incomingContinuation.finish()
        }
    }
}

private final class SilentActorTransport: ActorTransport, Sendable {
    private struct State: Sendable {
        var frames = 0
        var cancellations = 0
        var invocationCallIDs: [ActorCallID] = []
        var stopped = false
    }

    let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let continuation: AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let state = Mutex(State())

    init() {
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream()
        self.incoming = stream.stream
        self.continuation = stream.continuation
    }

    var sentFrameCount: Int {
        state.withLock { $0.frames }
    }

    var sentCancellationCount: Int {
        state.withLock { $0.cancellations }
    }

    var sentInvocationCount: Int {
        state.withLock { $0.invocationCallIDs.count }
    }

    var lastInvocationCallID: ActorCallID? {
        state.withLock { $0.invocationCallIDs.last }
    }

    func start() async throws {}

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        try state.withLock { state in
            guard !state.stopped else {
                throw ActorSystemError.transportClosed
            }
            state.frames += 1
            switch frame {
            case .invocation(let invocation):
                state.invocationCallIDs.append(invocation.callID)
            case .cancellation:
                state.cancellations += 1
            case .hello, .result:
                break
            }
        }
    }

    func receive(_ frame: ActorInboundFrame) throws {
        switch continuation.yield(frame) {
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

    func shutdown() async {
        let shouldFinish = state.withLock { state -> Bool in
            guard !state.stopped else {
                return false
            }
            state.stopped = true
            return true
        }
        if shouldFinish {
            continuation.finish()
        }
    }
}

private final class BlockingSendActorTransport: ActorTransport, Sendable {
    private struct State: Sendable {
        var sendStarted = false
        var sendCancelled = false
        var sendContinuation: CheckedContinuation<Void, Never>?
        var startWaiters: [CheckedContinuation<Void, Never>] = []
        var cancellationWaiters: [CheckedContinuation<Void, Never>] = []
        var stopped = false
    }

    let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let incomingContinuation:
        AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let state = Mutex(State())

    init() {
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream()
        self.incoming = stream.stream
        self.incomingContinuation = stream.continuation
    }

    func start() async throws {}

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        _ = frame
        _ = endpoint
        try state.withLock { state in
            guard !state.stopped else {
                throw ActorSystemError.transportClosed
            }
        }
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
                    state.sendStarted = true
                    state.sendContinuation = continuation
                    let waiters = state.startWaiters
                    state.startWaiters.removeAll(keepingCapacity: false)
                    return waiters
                }
                for waiter in waiters {
                    waiter.resume()
                }
            }
        } onCancel: {
            let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
                state.sendCancelled = true
                let waiters = state.cancellationWaiters
                state.cancellationWaiters.removeAll(keepingCapacity: false)
                return waiters
            }
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitUntilSendStarts() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = state.withLock { state in
                guard !state.sendStarted else {
                    return true
                }
                state.startWaiters.append(continuation)
                return false
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    func waitUntilSendIsCancelled() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = state.withLock { state in
                guard !state.sendCancelled else {
                    return true
                }
                state.cancellationWaiters.append(continuation)
                return false
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    func releaseSend() {
        let continuation = state.withLock { state -> CheckedContinuation<Void, Never>? in
            let continuation = state.sendContinuation
            state.sendContinuation = nil
            return continuation
        }
        continuation?.resume()
    }

    func shutdown() async {
        let continuation = state.withLock { state -> CheckedContinuation<Void, Never>? in
            guard !state.stopped else {
                return nil
            }
            state.stopped = true
            let continuation = state.sendContinuation
            state.sendContinuation = nil
            return continuation
        }
        continuation?.resume()
        incomingContinuation.finish()
    }
}

private struct AddressActorRouter: ActorRouter {
    let routes: [ActorAddress: ActorRoute]

    func route(to recipient: ActorAddress) async throws -> ActorRoute {
        guard let route = routes[recipient] else {
            throw ActorSystemError.routeNotFound(recipient)
        }
        return route
    }
}

private final class EndpointReportingActorTransport:
    ActorEndpointLifecycleReportingTransport,
    Sendable
{
    private struct State: Sendable {
        var sentFrames = 0
        var stopped = false
        var terminationHandler:
            (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    }

    let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let continuation: AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let state = Mutex(State())

    init() {
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream()
        self.incoming = stream.stream
        self.continuation = stream.continuation
    }

    var sentFrameCount: Int {
        state.withLock { $0.sentFrames }
    }

    func setEndpointTerminationHandler(
        _ handler: (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    ) async {
        state.withLock { $0.terminationHandler = handler }
    }

    func start() async throws {}

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        try state.withLock { state in
            guard !state.stopped else {
                throw ActorSystemError.transportClosed
            }
            state.sentFrames += 1
        }
    }

    func terminate(
        _ endpoint: ActorEndpoint,
        error: ActorSystemError
    ) async {
        let handler = state.withLock { $0.terminationHandler }
        await handler?(endpoint, error)
    }

    func shutdown() async {
        let shouldFinish = state.withLock { state -> Bool in
            guard !state.stopped else {
                return false
            }
            state.stopped = true
            state.terminationHandler = nil
            return true
        }
        if shouldFinish {
            continuation.finish()
        }
    }
}

private final class InlineTerminatingActorTransport:
    ActorEndpointLifecycleReportingTransport,
    Sendable
{
    private struct State: Sendable {
        var stopped = false
        var terminationHandler:
            (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    }

    let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let continuation: AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let state = Mutex(State())

    init() {
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream()
        incoming = stream.stream
        continuation = stream.continuation
    }

    func setEndpointTerminationHandler(
        _ handler: (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    ) async {
        state.withLock { $0.terminationHandler = handler }
    }

    func start() async throws {}

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        _ = frame
        let handler = try state.withLock { state in
            guard !state.stopped else {
                throw ActorSystemError.transportClosed
            }
            return state.terminationHandler
        }
        await handler?(endpoint, .transportClosed)
        throw ActorSystemError.transportClosed
    }

    func shutdown() async {
        let shouldFinish = state.withLock { state -> Bool in
            guard !state.stopped else {
                return false
            }
            state.stopped = true
            state.terminationHandler = nil
            return true
        }
        if shouldFinish {
            continuation.finish()
        }
    }
}

private final class ConsumerEndpointTerminatingActorTransport:
    ActorEndpointLifecycleReportingTransport,
    Sendable
{
    private struct State: Sendable {
        var stopped = false
        var sendStarted = false
        var sendContinuation: CheckedContinuation<Void, Never>?
        var sendStartWaiters: [CheckedContinuation<Void, Never>] = []
        var notificationStarted = false
        var notificationWaiters: [CheckedContinuation<Void, Never>] = []
        var terminationHandler:
            (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
        var consumerTask: Task<Void, Never>?
        var consumerCompleted = false
    }

    let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let continuation: AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let state = Mutex(State())

    init() {
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream()
        self.incoming = stream.stream
        self.continuation = stream.continuation
    }

    var consumerCompleted: Bool {
        state.withLock { $0.consumerCompleted }
    }

    func setEndpointTerminationHandler(
        _ handler: (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?
    ) async {
        state.withLock { $0.terminationHandler = handler }
    }

    func start() async throws {}

    func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        _ = (frame, endpoint)
        await withCheckedContinuation { continuation in
            let waiters = state.withLock {
                state -> [CheckedContinuation<Void, Never>] in
                state.sendStarted = true
                state.sendContinuation = continuation
                let waiters = state.sendStartWaiters
                state.sendStartWaiters.removeAll(keepingCapacity: false)
                return waiters
            }
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitUntilSendStarts() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = state.withLock { state -> Bool in
                guard !state.sendStarted else {
                    return true
                }
                state.sendStartWaiters.append(continuation)
                return false
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    func terminateFromConsumer(endpoint: ActorEndpoint) {
        let gate = ActorTaskStartGate()
        let task = Task {
            await gate.wait()
            let (handler, waiters) = self.state.withLock {
                state -> (
                    (@Sendable (ActorEndpoint, ActorSystemError) async -> Void)?,
                    [CheckedContinuation<Void, Never>]
                ) in
                state.notificationStarted = true
                let waiters = state.notificationWaiters
                state.notificationWaiters.removeAll(keepingCapacity: false)
                return (state.terminationHandler, waiters)
            }
            for waiter in waiters {
                waiter.resume()
            }
            await handler?(endpoint, .transportClosed)
            self.releaseSend()
            self.state.withLock { $0.consumerCompleted = true }
        }
        state.withLock { $0.consumerTask = task }
        gate.start()
    }

    func waitUntilNotificationStarts() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = state.withLock { state -> Bool in
                guard !state.notificationStarted else {
                    return true
                }
                state.notificationWaiters.append(continuation)
                return false
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    func shutdown() async {
        let consumerTask = state.withLock { state -> Task<Void, Never>? in
            guard !state.stopped else {
                return state.consumerTask
            }
            state.stopped = true
            state.terminationHandler = nil
            return state.consumerTask
        }
        if let consumerTask {
            await consumerTask.value
        } else {
            releaseSend()
        }
        continuation.finish()
    }

    private func releaseSend() {
        let continuation = state.withLock {
            state -> CheckedContinuation<Void, Never>? in
            let continuation = state.sendContinuation
            state.sendContinuation = nil
            return continuation
        }
        continuation?.resume()
    }
}

private func configuration(
    session: UInt64,
    maximumInFlightCalls: Int = 1_024,
    maximumRetainedInboundResults: Int = 4_096,
    clock: any ActorClock = ContinuousActorClock(),
    inboundInterceptor: any ActorInboundInvocationInterceptor = DirectActorInboundInvocationInterceptor()
) -> ActorSystemConfiguration {
    ActorSystemConfiguration(
        sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(session)),
        maximumInFlightCalls: maximumInFlightCalls,
        maximumRetainedInboundResults: maximumRetainedInboundResults,
        clock: clock,
        inboundInterceptor: inboundInterceptor
    )
}

private func eventually(
    _ condition: @escaping @Sendable () async -> Bool
) async {
    for _ in 0..<10_000 {
        if await condition() {
            return
        }
        await Task.yield()
    }
    Issue.record("Condition did not become true")
}
