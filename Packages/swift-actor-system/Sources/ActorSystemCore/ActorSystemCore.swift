import Synchronization

public final class ActorSystemCore: Sendable {
    private enum Phase: Sendable, Equatable {
        case initialized
        case starting
        case running
        case shuttingDown
        case stopped
    }

    private struct LifecycleState: Sendable {
        var phase: Phase = .initialized
        var startTask: Task<Void, any Error>?
        var termination: ActorSystemTermination?
        var stoppedTransports: Set<ActorTransportID> = []
    }

    private let directory: ActorDirectory
    private let router: any ActorRouter
    private let transports: [ActorTransportID: any ActorTransport]
    private let configuration: ActorSystemConfiguration
    private let ownedTaskOwner: ActorOwnedTaskOwner
    private let lifecycle = Mutex(LifecycleState())
    private let consumerTasks: ActorConsumerTaskRegistry
    private let pendingCalls: PendingCallRegistry
    private let outboundTasks: ActorOutboundTaskRegistry
    private let invocationTasks: ActorInvocationTaskRegistry
    private let remoteTimeoutTasks: ActorInvocationTaskRegistry
    private let endpointCallbackTasks: ActorInvocationTaskRegistry
    private let callIDGenerator = ActorCallIDGenerator()
    private let inboundScheduler: ActorInboundScheduler

    public init(
        directory: ActorDirectory = ActorDirectory(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration
    ) {
        self.directory = directory
        self.router = router
        self.transports = transports
        self.configuration = configuration
        let ownedTaskOwner = ActorOwnedTaskOwner()
        self.ownedTaskOwner = ownedTaskOwner
        self.consumerTasks = ActorConsumerTaskRegistry(owner: ownedTaskOwner)
        self.pendingCalls = PendingCallRegistry(
            maximumCount: configuration.maximumInFlightCalls
        )
        let (doubledOutboundLimit, outboundLimitOverflow) =
            configuration.maximumInFlightCalls.multipliedReportingOverflow(by: 2)
        self.outboundTasks = ActorOutboundTaskRegistry(
            maximumCount: configuration.maximumInFlightCalls <= 0
                ? 0
                : (outboundLimitOverflow ? Int.max : doubledOutboundLimit),
            owner: ownedTaskOwner
        )
        self.invocationTasks = ActorInvocationTaskRegistry(
            maximumCount: configuration.maximumInFlightCalls <= 0
                ? 0
                : (outboundLimitOverflow ? Int.max : doubledOutboundLimit),
            owner: ownedTaskOwner
        )
        self.remoteTimeoutTasks = ActorInvocationTaskRegistry(
            maximumCount: configuration.maximumInFlightCalls,
            owner: ownedTaskOwner,
            taskKind: .remoteTimeout
        )
        self.endpointCallbackTasks = ActorInvocationTaskRegistry(
            maximumCount: configuration.maximumTransportEndpoints,
            owner: ownedTaskOwner,
            taskKind: .endpointCallback
        )
        self.inboundScheduler = ActorInboundScheduler(
            maximumConcurrentCalls: configuration.maximumConcurrentInboundCalls,
            maximumRetainedResults: configuration.maximumRetainedInboundResults,
            owner: ownedTaskOwner
        )
    }

    public func start() async throws {
        let gate = ActorTaskStartGate()
        let task = try lifecycle.withLock { state -> Task<Void, any Error> in
            switch state.phase {
            case .initialized:
                state.phase = .starting
            case .starting, .running:
                throw ActorSystemError.alreadyStarted
            case .shuttingDown, .stopped:
                throw ActorSystemError.shuttingDown
            }
            let identity = ActorOwnedTaskIdentity(owner: ownedTaskOwner, kind: .start)
            let task = Task {
                try await ActorOwnedTaskContext.$current.withValue(identity) {
                    await gate.wait()
                    try await self.performStart()
                }
            }
            state.startTask = task
            return task
        }
        gate.start()

        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            lifecycle.withLock { state in
                state.startTask = nil
            }
        } catch {
            lifecycle.withLock { state in
                state.startTask = nil
                if state.phase == .starting {
                    state.phase = .initialized
                }
            }
            let termination = requestShutdown()
            try await termination.wait()
            if error is CancellationError {
                throw ActorSystemError.shuttingDown
            }
            throw error
        }
    }

    private func performStart() async throws {
        var startedTransports: [(ActorTransportID, any ActorTransport)] = []
        do {
            try validateConfiguration()
            try requireStartNotCancelled()
            let session = try await configuration.sessionIdentitySource.makeSessionID()
            guard session.rawValue != 0 else {
                throw ActorSystemError.sessionIdentityUnavailable
            }
            callIDGenerator.activate(session: session)

            for (id, transport) in transports.sorted(by: {
                $0.key.rawValue < $1.key.rawValue
            }) {
                try requireStartNotCancelled()
                await transport.setEndpointTerminationHandler { [self] endpoint, error in
                    await self.reportEndpointClosed(
                        transport: id,
                        endpoint: endpoint,
                        error: error
                    )
                }
                do {
                    try await transport.start()
                } catch {
                    await transport.setEndpointTerminationHandler(nil)
                    await shutdownTransportOnce(id: id, transport: transport)
                    throw error
                }
                try requireStartNotCancelled()
                startedTransports.append((id, transport))
            }

            let mayRun = lifecycle.withLock { state -> Bool in
                guard state.phase == .starting else {
                    return false
                }
                state.phase = .running
                return true
            }
            guard mayRun else {
                throw ActorSystemError.shuttingDown
            }
            try installConsumers(for: startedTransports)
        } catch {
            for (id, transport) in startedTransports.reversed() {
                await transport.setEndpointTerminationHandler(nil)
                await shutdownTransportOnce(id: id, transport: transport)
            }
            throw error
        }
    }

    private func shutdownTransportOnce(
        id: ActorTransportID,
        transport: any ActorTransport
    ) async {
        let ownsShutdown = lifecycle.withLock { state in
            state.stoppedTransports.insert(id).inserted
        }
        guard ownsShutdown else {
            return
        }
        await transport.shutdown()
    }

    private func requireStartNotCancelled() throws {
        guard !Task.isCancelled else {
            throw CancellationError()
        }
    }

    public func invoke(
        _ invocation: ActorInvocation,
        options: ActorCallOptions = .defaults
    ) async throws -> ActorInvocationResult {
        try requireRunning()
        guard !Task.isCancelled else {
            throw ActorSystemError.cancelled
        }
        try validateInvocationBounds(invocation)
        let timeoutNanoseconds = try ActorDuration.nanoseconds(options.timeout)
        let callID = try callIDGenerator.next()

        let hasLocalTarget = directory.target(for: invocation.recipient) != nil
        let claimsLocalInvocation: Bool
        if hasLocalTarget {
            claimsLocalInvocation = true
        } else {
            claimsLocalInvocation = await configuration.inboundInterceptor
                .claimsLocalInvocation(
                for: invocation.recipient
            )
        }

        if claimsLocalInvocation {
            let context = ActorInvocationContext(
                callID: callID,
                origin: .local,
                remainingTimeout: options.timeout,
                metadata: ActorByteBuffer()
            )
            let execution = ActorInvocationExecution {
                guard let target = self.directory.target(
                    for: invocation.recipient
                ) else {
                    throw ActorSystemError.actorNotFound(invocation.recipient)
                }
                try self.validate(invocation, against: target)
                return try await target.invoke(invocation, context: context)
            }
            let invoke: @Sendable () async throws -> ActorInvocationResult = {
                try await self.configuration.inboundInterceptor.intercept(
                    invocation,
                    context: context,
                    execution: execution
                )
            }
            let result: ActorInvocationResult
            if let timeout = options.timeout {
                result = try await ActorInvocationDeadline<ActorInvocationResult>().run(
                    timeout: timeout,
                    clock: configuration.clock,
                    taskRegistry: invocationTasks
                ) { try await invoke() }
            } else {
                do {
                    result = try await ActorInvocationDeadline<ActorInvocationResult>().run(
                        taskRegistry: invocationTasks,
                        operation: invoke
                    )
                } catch is CancellationError {
                    throw ActorSystemError.cancelled
                }
            }
            try validateResultBounds(result)
            return result
        }

        let route = try await router.route(to: invocation.recipient)
        guard let transport = transports[route.transport] else {
            throw ActorSystemError.transportUnavailable(route.transport)
        }
        let frame = ActorFrame.invocation(
            ActorInvocationFrame(
                callID: callID,
                invocation: invocation,
                remainingTimeoutNanoseconds: timeoutNanoseconds
            )
        )
        let outboundSend = ActorOutboundSendState()

        let outcome = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                do {
                    try pendingCalls.register(
                        callID: callID,
                        transport: route.transport,
                        endpoint: route.endpoint,
                        continuation: continuation
                    )
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let wasCancelled = withUnsafeCurrentTask { task in
                    task?.isCancelled ?? false
                }
                if wasCancelled {
                    pendingCalls.fail(callID: callID, error: ActorSystemError.cancelled)
                    return
                }

                if let timeout = options.timeout {
                    do {
                        let timeoutTask = try remoteTimeoutTasks.schedule { [self] in
                            do {
                                try await self.configuration.clock.sleep(for: timeout)
                                let didTimeout = self.pendingCalls.timeout(callID: callID)
                                if didTimeout {
                                    self.scheduleCancellation(
                                        callID: callID,
                                        kind: .timeoutCancellation,
                                        transportID: route.transport,
                                        transport: transport,
                                        endpoint: route.endpoint,
                                        outboundSend: outboundSend
                                    )
                                }
                            } catch is CancellationError {
                                return
                            } catch {
                                self.pendingCalls.fail(callID: callID, error: error)
                            }
                        }
                        pendingCalls.installTimeout(timeoutTask, for: callID)
                    } catch {
                        pendingCalls.fail(callID: callID, error: error)
                        return
                    }
                }

                let scheduleResult = outboundTasks.schedule(
                    key: .init(callID: callID, kind: .invocation),
                    transport: route.transport,
                    endpoint: route.endpoint
                ) {
                    guard !Task.isCancelled else {
                        outboundSend.markFailed()
                        self.pendingCalls.fail(
                            callID: callID,
                            error: ActorSystemError.shuttingDown
                        )
                        return
                    }
                    do {
                        try await transport.send(frame, to: route.endpoint)
                        outboundSend.markSent()
                    } catch {
                        outboundSend.markFailed()
                        self.pendingCalls.fail(callID: callID, error: error)
                    }
                }
                switch scheduleResult {
                case .scheduled:
                    break
                case .shuttingDown:
                    outboundSend.markFailed()
                    pendingCalls.fail(
                        callID: callID,
                        error: ActorSystemError.shuttingDown
                    )
                case .overloaded, .duplicate:
                    outboundSend.markFailed()
                    pendingCalls.fail(
                        callID: callID,
                        error: ActorSystemError.overloaded
                    )
                }
            }
        } onCancel: {
            let didCancel = pendingCalls.fail(
                callID: callID,
                error: ActorSystemError.cancelled
            )
            if didCancel {
                scheduleCancellation(
                    callID: callID,
                    kind: .callerCancellation,
                    transportID: route.transport,
                    transport: transport,
                    endpoint: route.endpoint,
                    outboundSend: outboundSend
                )
            }
        }

        return try result(from: outcome, invocation: invocation)
    }

    public func receive(_ inbound: ActorInboundFrame) async {
        if let violation = inboundViolation(inbound) {
            switch inbound.frame {
            case .invocation(let frame):
                await send(
                    outcome: .systemFailure(ActorSystemFailure(error: violation)),
                    callID: frame.callID,
                    to: inbound
                )
            case .result(let frame):
                pendingCalls.fail(
                    callID: frame.callID,
                    from: inbound.transport,
                    endpoint: inbound.replyEndpoint,
                    error: violation
                )
            case .cancellation, .hello:
                break
            }
            return
        }
        switch inbound.frame {
        case .result(let result):
            pendingCalls.complete(
                callID: result.callID,
                from: inbound.transport,
                endpoint: inbound.replyEndpoint,
                outcome: result.outcome
            )
        case .cancellation(let callID):
            await inboundScheduler.cancel(
                callID: callID,
                transport: inbound.transport,
                endpoint: inbound.replyEndpoint
            )
        case .hello(let hello):
            if hello.maximumWireVersion < ActorFrameCodec.wireVersion {
                pendingCalls.failCalls(
                    using: inbound.transport,
                    endpoint: inbound.replyEndpoint,
                    error: ActorSystemError.unsupportedWireVersion(hello.maximumWireVersion)
                )
            }
        case .invocation(let frame):
            await receiveInvocation(frame, from: inbound)
        }
    }

    private func inboundViolation(
        _ inbound: ActorInboundFrame
    ) -> ActorSystemError? {
        guard inbound.metadata.count <= configuration.maximumIdentityBytes else {
            return .invalidFrame(
                ActorProtocolViolation("Inbound transport metadata exceeds the configured limit")
            )
        }
        switch inbound.frame {
        case .invocation(let frame):
            guard frame.callID.session.rawValue != 0, frame.callID.sequence != 0 else {
                return .invalidFrame(
                    ActorProtocolViolation("Inbound invocation call identity is invalid")
                )
            }
            guard frame.invocation.payload.count <= configuration.maximumPayloadBytes,
                  frame.invocation.recipient.identity.utf8.count <= configuration.maximumIdentityBytes
            else {
                return .invalidFrame(
                    ActorProtocolViolation("Inbound invocation exceeds the configured limits")
                )
            }
        case .result(let frame):
            guard frame.callID.session.rawValue != 0, frame.callID.sequence != 0 else {
                return .invalidFrame(
                    ActorProtocolViolation("Inbound result call identity is invalid")
                )
            }
            let payloadCount: Int
            switch frame.outcome {
            case .success(let result):
                payloadCount = result.payload.count
            case .systemFailure(let failure):
                payloadCount = failure.metadata.count
            case .applicationFailure(let failure):
                payloadCount = failure.payload.count
            }
            guard payloadCount <= configuration.maximumPayloadBytes else {
                return .invalidFrame(
                    ActorProtocolViolation("Inbound result exceeds the configured payload limit")
                )
            }
        case .cancellation(let callID):
            guard callID.session.rawValue != 0, callID.sequence != 0 else {
                return .invalidFrame(
                    ActorProtocolViolation("Inbound cancellation call identity is invalid")
                )
            }
        case .hello(let hello):
            guard hello.session.rawValue != 0 else {
                return .invalidFrame(
                    ActorProtocolViolation("Inbound hello session identity is invalid")
                )
            }
        }
        return nil
    }

    public func requestShutdown() -> ActorSystemTermination {
        let ownedTaskOwner = self.ownedTaskOwner
        let operation: @Sendable () async throws -> Void = { [self] in
            await ActorOwnedTaskContext.$current.withValue(nil) {
                await self.performShutdown()
            }
        }
        return lifecycle.withLock { state in
            if let termination = state.termination {
                return termination
            }
            guard state.phase != .stopped else {
                return .alreadyTerminated()
            }
            state.phase = .shuttingDown
            let termination = ActorSystemTermination(
                waitIsReentrant: {
                    ActorOwnedTaskContext.current?.contains(owner: ownedTaskOwner) == true
                },
                operation: operation
            )
            state.termination = termination
            return termination
        }
    }

    public func shutdown() async throws {
        try await requestShutdown().wait()
    }

    private func performShutdown() async {

        let startTask = lifecycle.withLock { $0.startTask }
        if let startTask {
            startTask.cancel()
            for (id, transport) in transports {
                await transport.setEndpointTerminationHandler(nil)
                await shutdownTransportOnce(id: id, transport: transport)
            }
            do {
                try await startTask.value
            } catch {
                // Startup rollback and terminal shutdown continue below.
            }
            lifecycle.withLock { state in
                state.startTask = nil
            }
        }

        pendingCalls.failAll(error: ActorSystemError.shuttingDown)
        for (_, transport) in transports {
            await transport.setEndpointTerminationHandler(nil)
        }
        let inboundTaskHandles = await inboundScheduler.stopAcceptingAndCancel()
        let outboundTaskHandles = outboundTasks.stopAcceptingAndCancel()
        let invocationTaskHandles = invocationTasks.stopAcceptingAndCancel()
        let remoteTimeoutTaskHandles = remoteTimeoutTasks.stopAcceptingAndCancel()
        let endpointCallbackTaskHandles = endpointCallbackTasks.stopAcceptingAndCancel()

        let tasks = consumerTasks.stopAcceptingAndCancel()
        for (id, transport) in transports {
            await shutdownTransportOnce(id: id, transport: transport)
        }
        for task in inboundTaskHandles
            + outboundTaskHandles
            + invocationTaskHandles
            + remoteTimeoutTaskHandles
            + endpointCallbackTaskHandles
            + tasks {
            await task.value
        }
        _ = directory.removeAll()

        lifecycle.withLock { state in
            state.phase = .stopped
        }
    }

    private func reportEndpointClosed(
        transport: ActorTransportID,
        endpoint: ActorEndpoint,
        error: ActorSystemError
    ) async {
        do {
            _ = try endpointCallbackTasks.schedule {
                await self.endpointClosed(
                    transport: transport,
                    endpoint: endpoint,
                    error: error
                )
            }
        } catch {
            // Terminal shutdown performs the same registry cleanup globally.
            // A callback arriving after admission closes returns promptly.
        }
    }

    private func validateConfiguration() throws {
        guard configuration.maximumInFlightCalls > 0,
              configuration.maximumConcurrentInboundCalls > 0,
              configuration.maximumRetainedInboundResults >= 0,
              configuration.maximumTransportEndpoints > 0,
              configuration.maximumFrameBytes >= ActorFrameCodec.minimumFrameBytes,
              configuration.maximumPayloadBytes >= 0,
              configuration.maximumPayloadBytes <= configuration.maximumFrameBytes,
              configuration.maximumIdentityBytes >= 0,
              configuration.maximumNestingDepth > 0,
              configuration.maximumCollectionElements >= 0,
              transports.keys.allSatisfy({ !$0.rawValue.isEmpty })
        else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor system configuration is invalid")
            )
        }
    }

    private func requireRunning() throws {
        try lifecycle.withLock { state in
            switch state.phase {
            case .running:
                return
            case .shuttingDown, .stopped:
                throw ActorSystemError.shuttingDown
            case .initialized, .starting:
                throw ActorSystemError.notStarted
            }
        }
    }

    private func installConsumers(
        for startedTransports: [(ActorTransportID, any ActorTransport)]
    ) throws {
        for entry in startedTransports {
            let (id, transport) = entry
            try consumerTasks.schedule(transport: id) {
                do {
                    for try await inbound in transport.incoming {
                        await self.receive(inbound)
                    }
                    await self.transportClosed(id: id)
                } catch {
                    await self.transportClosed(id: id, error: error)
                }
            }
        }
    }

    private func transportClosed(
        id: ActorTransportID,
        error: (any Error)? = nil
    ) async {
        pendingCalls.failCalls(
            using: id,
            error: error ?? ActorSystemError.transportClosed
        )
        await outboundTasks.transportClosed(id)
        await inboundScheduler.transportClosed(id)
    }

    private func receiveInvocation(
        _ frame: ActorInvocationFrame,
        from inbound: ActorInboundFrame
    ) async {
        do {
            try requireRunning()
            try await inboundScheduler.submit(
                callID: frame.callID,
                transport: inbound.transport,
                endpoint: inbound.replyEndpoint,
                reply: { outcome in
                    await self.send(
                        outcome: outcome,
                        callID: frame.callID,
                        to: inbound
                    )
                }
            ) {
                await self.executeInbound(frame, from: inbound)
            }
        } catch let error as ActorSystemError {
            await send(
                outcome: .systemFailure(ActorSystemFailure(error: error)),
                callID: frame.callID,
                to: inbound
            )
        } catch {
            await send(
                outcome: .systemFailure(
                    ActorSystemFailure(code: .remoteFailure)
                ),
                callID: frame.callID,
                to: inbound
            )
        }
    }

    private func endpointClosed(
        transport: ActorTransportID,
        endpoint: ActorEndpoint,
        error: ActorSystemError
    ) async {
        pendingCalls.failCalls(
            using: transport,
            endpoint: endpoint,
            error: error
        )
        await outboundTasks.endpointClosed(
            transport: transport,
            endpoint: endpoint
        )
        await inboundScheduler.endpointClosed(
            transport: transport,
            endpoint: endpoint
        )
    }

    private func executeInbound(
        _ frame: ActorInvocationFrame,
        from inbound: ActorInboundFrame
    ) async -> ActorInvocationOutcome {
        let outcome: ActorInvocationOutcome
        do {
            let timeout = try ActorDuration.duration(
                nanoseconds: frame.remainingTimeoutNanoseconds
            )
            let context = ActorInvocationContext(
                callID: frame.callID,
                origin: .remote(
                    transport: inbound.transport,
                    endpoint: inbound.replyEndpoint
                ),
                remainingTimeout: timeout,
                metadata: inbound.metadata
            )
            let execution = ActorInvocationExecution {
                guard let target = self.directory.target(
                    for: frame.invocation.recipient
                ) else {
                    throw ActorSystemError.actorNotFound(frame.invocation.recipient)
                }
                try self.validate(frame.invocation, against: target)
                return try await target.invoke(frame.invocation, context: context)
            }
            let invoke: @Sendable () async throws -> ActorInvocationResult = {
                try await self.configuration.inboundInterceptor.intercept(
                    frame.invocation,
                    context: context,
                    execution: execution
                )
            }
            let result: ActorInvocationResult
            if let timeout {
                result = try await ActorInvocationDeadline<ActorInvocationResult>().run(
                    timeout: timeout,
                    clock: configuration.clock,
                    taskRegistry: invocationTasks,
                    operation: invoke
                )
            } else {
                result = try await invoke()
            }
            try validateResultBounds(result)
            outcome = .success(result)
        } catch let failure as ActorApplicationFailure {
            if failure.payload.count <= configuration.maximumPayloadBytes {
                outcome = .applicationFailure(failure)
            } else {
                outcome = .systemFailure(
                    ActorSystemFailure(error: ActorSystemError.encodingFailed)
                )
            }
        } catch let error as ActorSystemError {
            outcome = .systemFailure(ActorSystemFailure(error: error))
        } catch is CancellationError {
            outcome = .systemFailure(ActorSystemFailure(code: .cancelled))
        } catch {
            outcome = .systemFailure(ActorSystemFailure(code: .remoteFailure))
        }
        return outcome
    }

    private func scheduleCancellation(
        callID: ActorCallID,
        kind: ActorOutboundTaskRegistry.Kind,
        transportID: ActorTransportID,
        transport: any ActorTransport,
        endpoint: ActorEndpoint,
        outboundSend: ActorOutboundSendState
    ) {
        outboundTasks.schedule(
            key: .init(callID: callID, kind: kind),
            transport: transportID,
            endpoint: endpoint
        ) {
            guard await outboundSend.invocationWasSent(),
                  !Task.isCancelled
            else {
                return
            }
            do {
                try await transport.send(.cancellation(callID), to: endpoint)
            } catch {
                // Cancellation is best effort after the caller has already
                // observed cancellation or timeout.
            }
        }
    }

    private func send(
        outcome: ActorInvocationOutcome,
        callID: ActorCallID,
        to inbound: ActorInboundFrame
    ) async {
        guard let transport = transports[inbound.transport] else {
            return
        }
        do {
            try await transport.send(
                .result(ActorResultFrame(callID: callID, outcome: outcome)),
                to: inbound.replyEndpoint
            )
        } catch {
            pendingCalls.failCalls(
                using: inbound.transport,
                endpoint: inbound.replyEndpoint,
                error: error
            )
        }
    }

    private func validate(
        _ invocation: ActorInvocation,
        against target: any ActorInvocationTarget
    ) throws {
        guard target.address == invocation.recipient else {
            throw ActorSystemError.actorNotFound(invocation.recipient)
        }
        guard target.descriptor.schemaFingerprint == invocation.schemaFingerprint else {
            throw ActorSystemError.schemaMismatch(
                ActorSchemaMismatch(
                    expected: target.descriptor.schemaFingerprint,
                    received: invocation.schemaFingerprint
                )
            )
        }
        guard target.descriptor.method(id: invocation.method) != nil else {
            throw ActorSystemError.targetUnavailable(invocation.method)
        }
    }

    private func validateInvocationBounds(_ invocation: ActorInvocation) throws {
        guard invocation.payload.count <= configuration.maximumPayloadBytes,
              invocation.recipient.identity.utf8.count <= configuration.maximumIdentityBytes
        else {
            throw ActorSystemError.encodingFailed
        }
    }

    private func validateResultBounds(_ result: ActorInvocationResult) throws {
        guard result.payload.count <= configuration.maximumPayloadBytes else {
            throw ActorSystemError.encodingFailed
        }
    }

    private func result(
        from outcome: ActorInvocationOutcome,
        invocation: ActorInvocation
    ) throws -> ActorInvocationResult {
        switch outcome {
        case .success(let result):
            return result
        case .applicationFailure(let failure):
            throw failure
        case .systemFailure(let failure):
            throw mappedRemoteError(failure, invocation: invocation)
        }
    }

    private func mappedRemoteError(
        _ failure: ActorSystemFailure,
        invocation: ActorInvocation
    ) -> ActorSystemError {
        switch failure.code {
        case .notStarted: .notStarted
        case .shuttingDown: .shuttingDown
        case .invalidFrame:
            .invalidFrame(ActorProtocolViolation("The remote peer rejected the frame"))
        case .unsupportedWireVersion:
            failure.decodedUnsupportedWireVersion()
                .map(ActorSystemError.unsupportedWireVersion)
                ?? .remoteFailure(ActorRemoteFailure(code: failure.code.rawValue))
        case .schemaMismatch:
            failure.decodedSchemaMismatch()
                .map(ActorSystemError.schemaMismatch)
                ?? .remoteFailure(ActorRemoteFailure(code: failure.code.rawValue))
        case .actorNotFound: .actorNotFound(invocation.recipient)
        case .targetUnavailable: .targetUnavailable(invocation.method)
        case .unauthorized: .unauthorized
        case .activationFailed: .activationFailed
        case .encodingFailed: .encodingFailed
        case .decodingFailed: .decodingFailed
        case .routeNotFound: .routeNotFound(invocation.recipient)
        case .transportUnavailable:
            .remoteFailure(ActorRemoteFailure(code: failure.code.rawValue))
        case .transportClosed: .transportClosed
        case .timeout: .timeout
        case .cancelled: .cancelled
        case .overloaded: .overloaded
        case .remoteFailure:
            .remoteFailure(
                ActorRemoteFailure(
                    code: failure.decodedRemoteFailureCode() ?? failure.code.rawValue
                )
            )
        case .sessionIdentityUnavailable, .callSequenceExhausted, .alreadyStarted:
            .remoteFailure(ActorRemoteFailure(code: failure.code.rawValue))
        }
    }
}

private final class ActorOutboundSendState: Sendable {
    private enum Phase: Sendable, Equatable {
        case sending
        case sent
        case failed
    }

    private struct State: Sendable {
        var phase = Phase.sending
        var waiters: [CheckedContinuation<Bool, Never>] = []
    }

    private let state = Mutex(State())

    func markSent() {
        finish(with: .sent)
    }

    func markFailed() {
        finish(with: .failed)
    }

    func invocationWasSent() async -> Bool {
        await withCheckedContinuation { continuation in
            let immediate = state.withLock { state -> Bool? in
                switch state.phase {
                case .sent:
                    return true
                case .failed:
                    return false
                case .sending:
                    state.waiters.append(continuation)
                    return nil
                }
            }
            if let immediate {
                continuation.resume(returning: immediate)
            }
        }
    }

    private func finish(with result: Phase) {
        let completed = state.withLock { state -> [CheckedContinuation<Bool, Never>] in
            guard state.phase == .sending else {
                return []
            }
            state.phase = result
            let completed = state.waiters
            state.waiters.removeAll(keepingCapacity: false)
            return completed
        }
        for waiter in completed {
            waiter.resume(returning: result == .sent)
        }
    }
}
